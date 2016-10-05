# Enabling I2S
............

From: https://www.raspberrypi.org/forums/viewtopic.php?f=44&t=91237&start=50

The default ALSA sound devices supported by the Raspberry Pi 3 are PWM audio output jack and HDMI output. To run this demonstration I2S input and output needs to be enabled. The goal is to use a simple I2S interface that does not depend on a particular DAC or CODEC device that requires configuration over I2C or SPI.

To avoid recompilation of the Linux kernel a loadable kernel module is used.  This enables the driver for the I2S peripheral inside the BCM2708 device to be loaded dynamically.

A full description of how to do this can be found in the link below [#]_, however a brief summary of the required steps, found to work on a clean copy of Debian Jessie shipped with ``Noobs``, is show below:

.. [#] http://www.raspberrypi.org/forums/viewtopic.php?f=44&t=91237

First, update the Raspbian Linux distribution to the latest version (version 4.4.13v7 tested). This may take a few hours::

   sudo apt-get update
   sudo apt-get dist-upgrade

Before proceeding with the next steps, ensure you have re-booted your Raspberry Pi so that it is running the latest version of Raspbian that you have just downloaded. This can be done using the following command::

   sudo reboot

Next, we need to enable I2S in device tree. To do this, edit the file ``/boot/config.txt`` to remove the comment on line 47::

   dtparam=i2s=on

The sound card driver depends on the I2S peripheral and Direct Memory Access Controller modules which need to be added to  file. To do this, add the following lines to ``/etc/modules`` using your favorite text editor prefixed with ``sudo`` to ensure super user privileges::

   snd_soc_bcm2708
   snd_soc_bcm2708_i2s
   bcm2708_dmaengine

Next, download the kernel source (this may also take a long time to download and extract). The source download script requires the installation of two helper applications that are not installed by default. The installation of these is included below::

   sudo apt-get install bc
   sudo apt-get install libncurses5-dev
   git clone http://github.com/notro/rpi-source
   cd rpi-source
   python rpi-source
   cd ..

Now we have the kernel source downloaded, we can modify the driver source and build the modules needed to enable I2S. We require two modules --- one called ``loader`` which instantiates the sound-card module and the other is ``asoc_simple_card`` which is the sound card driver itself.

For further information on building and loading modules under Linux the link below provides a useful reference [#]_. 

.. [#] http://www.cyberciti.biz/tips/build-linux-kernel-module-against-installed-kernel-source-tree.html

Next we need to build the simple sound card driver::

   mkdir snd_driver
   cd snd_driver
   cp ../linux/sound/soc/generic/simple-card.c ./asoc_simple_card.c

Note that the directory ``linux`` will appended with a long hash. Please use this directory in the above copy command.
E.g. ``/linux-e88b69aa792dbe2b289ff528c0d07303068aa0aa/``.

The file needs a small modification to work around a bug (uninitialized BCLK ratio, causing the default of 100 bit clocks per I2S frame rather than the required 64 bit). To make this correction, at the end of function ``asoc_simple_card_dai_init`` around line number 213, add the following  source lines::

   ret = snd_soc_dai_set_bclk_ratio(cpu, 64);
   pr_alert("BCLK ratio set to 64!\n");

Use this makefile to build the module.
i.e. copy the contents into ``Makefile``. Note that the last line must be indented using a tab character rather than using spaces to avoid a build error::

   obj-m := asoc_simple_card.o
   KDIR := /lib/modules/$(shell uname -r)/build
   PWD := $(shell pwd)
   default:
          $(MAKE) -C $(KDIR) SUBDIRS=$(PWD) modules

And finally build the module, insert it into the kernel, and prepare for the next step::

   make
   sudo insmod asoc_simple_card.ko
   cd ..


You should see a console output similar to this::

   pi@raspberrypi:~/snd_driver $ make
   make -C /lib/modules/4.4.13-v7+/build SUBDIRS=/home/pi/snd_driver modules
   make[1]: Entering directory '/home/pi/linux-e88b69aa792dbe2b289ff528c0d07303068aa0aa'
     CC [M]  /home/pi/snd_driver/asoc_simple_card.o
     Building modules, stage 2.
     MODPOST 1 modules
     CC      /home/pi/snd_driver/asoc_simple_card.mod.o
     LD [M]  /home/pi/snd_driver/asoc_simple_card.ko
   make[1]: Leaving directory '/home/pi/linux-e88b69aa792dbe2b289ff528c0d07303068aa0aa'

Next we build the loader which presents the device to the OS::

   mkdir loader
   cd loader

Copy the contents of the source from the forum post linked [#]_ below into a new file called ``loader.c``.

For reference, a copy of the relevant code from the post is included here::

   #include <linux/module.h>
   #include <linux/kernel.h>
   #include <linux/kmod.h>
   #include <linux/platform_device.h>
   #include <sound/simple_card.h>
   #include <linux/delay.h>
   /*
   modified for linux 4.1.5
   inspired by https://github.com/msperl/spi-config
   with thanks for https://github.com/notro/rpi-source/wiki
   as well as Florian Meier for the rpi i2s and dma drivers

   to use a differant (simple-card compatible) codec
   change the codec name string in two places and the
   codec_dai name string. (see codec's source file)

   fmt flags are set for vanilla i2s with rpi as clock slave

   N.B. playback vs capture is determined by the codec choice
    */

   void device_release_callback(struct device *dev) { /* do nothing */ };

   static struct asoc_simple_card_info snd_rpi_simple_card_info = {
      .card = "snd_rpi_simple_card", // -> snd_soc_card.name
      .name = "simple-card_codec_link", // -> snd_soc_dai_link.name
      .codec = "snd-soc-dummy", // -> snd_soc_dai_link.codec_name
      .platform = "3f203000.i2s",
      .daifmt = SND_SOC_DAIFMT_I2S | SND_SOC_DAIFMT_NB_NF | SND_SOC_DAIFMT_CBS_CFM,
      .cpu_dai = {
         .name = "3f203000.i2s", // -> snd_soc_dai_link.cpu_dai_name
         .sysclk = 0
      },
      .codec_dai = {
         .name = "snd-soc-dummy-dai", // -> snd_soc_dai_link.codec_dai_name
         .sysclk = 0
      },
   };
   static struct platform_device snd_rpi_simple_card_device = {
      .name = "asoc-simple-card", //module alias
      .id = 0,
      .num_resources = 0,
      .dev = {
         .release = &device_release_callback,
         .platform_data = &snd_rpi_simple_card_info, // *HACK ALERT*
      },
   };
   int hello_init(void)
   {
      const char *dmaengine = "bcm2708-dmaengine"; //module name
      int ret;

      ret = request_module(dmaengine);
      pr_alert("request module load '%s': %d\n",dmaengine, ret);
      ret = platform_device_register(&snd_rpi_simple_card_device);
      pr_alert("register platform device '%s': %d\n",snd_rpi_simple_card_device.name, ret);

      pr_alert("Hello World :)\n");
      return 0;
   }
   void hello_exit(void)
   {// you'll have to sudo modprobe -r the card & codec drivers manually (first?)
      platform_device_unregister(&snd_rpi_simple_card_device);
      pr_alert("Goodbye World!\n");
   }
   module_init(hello_init);
   module_exit(hello_exit);
   MODULE_DESCRIPTION("ASoC simple-card I2S setup");
   MODULE_AUTHOR("Plugh Plover");
   MODULE_LICENSE("GPL v2"); 


Make sure that line 21 is changes as shown below to ensure the Raspberry Pi 3 is the I2S master and the Microphone is the slave::

   .daifmt = SND_SOC_DAIFMT_I2S | SND_SOC_DAIFMT_NB_NF | SND_SOC_DAIFMT_CBS_CFS,


.. [#] https://www.raspberrypi.org/forums/viewtopic.php?p=914713#p914713

Copy the below contents into ``Makefile`` again ensuring that the indent is a tab character rather than spaces::

   obj-m := loader.o
   KDIR := /lib/modules/$(shell uname -r)/build
   PWD := $(shell pwd)
   default:
          $(MAKE) -C $(KDIR) SUBDIRS=$(PWD) modules

And finally build the module and insert it into the kernel::

   make
   sudo insmod loader.ko
   cd ..


To verify that the I2S audio device driver module has been loaded and is accessible, you run the following command::

   arecord -l

This should generate a list of available ALSA captures devices something like this::

   **** List of CAPTURE Hardware Devices ****
   card 1: sndrpisimplecar [snd_rpi_simple_card], device 0: simple-card_codec_link snd-soc-dummy-dai-0 []
     Subdevices: 1/1
     Subdevice #0: subdevice #0

The physical sound card device presents a stereo I2S device to Linux. However, some Voice Assistant software such as Amazon's Alexa, requires access to a mono capture device. To present the stereo sound card as a mono device it is necessary to create a virtual mono capture device connected to the physical stereo capture device in ALSA. The microphone audio sent from the Microphone is a mono signal repeated on both stereo channels and so either channel will provide the required signal. The virtual mono capture device then needs to be set as the default device so that the client software picks it first when searching for input devices.

To setup the virtual capture device, modify the file ``.asoundrc`` found in the home directory as follows::

   pcm.monocard {
     type plug
     slave.pcm "plughw:1,0"
     slave.channels  2
     slave.rate 16000
   }

   ctl.monocard {
     type hw
     card 1
     device 0
   }

   pcm.!default {
      type asym
      playback.pcm {
         type hw
         card 0
      }
      capture.pcm {
         type plug
         slave.pcm "monocard"
      }
   }

   ctl.!default {
      type asym
      playback.pcm {
         type hw
         card 0
      }
      capture.pcm {
         type plug
         slave.pcm "monocard"
      }
   }

The above configuration keeps the default playback device as the 3.5mm jack on the Raspberry Pi however this can be changed to the I2S bus by changing the contents of for both ``pcm.!default {`` and ``ctl.!default {`` so that the ``playback.pcm {`` entries match ``capture.pcm``.

To apply the changes made in ``.asoundrc`` and enable the virtual capture device either reboot the Raspberry Pi or use the following command::

   sudo /etc/init.d/alsa-utils restart

Following the instructions given so far will enable the I2S soundcard in the current session. To make it available after reach reboot, it is necessary to load the modules at boot time. You can do this by adding a boot-time cron job to run the following script. Save this script as ``load_i2s_driver.sh`` in your home directory::

   cd ~
   sudo insmod snd_driver/asoc_simple_card.ko
   sudo insmod loader/loader.ko

The script can be auto-run at boot time by adding the following line in the editor window that appears after typing ``crontab -e``::

   @reboot /home/pi/load_i2s_driver.sh