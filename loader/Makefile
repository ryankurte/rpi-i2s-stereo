# Sound driver makefile

obj-m := loader.o
KDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)
   
build:
	$(MAKE) -C $(KDIR) SUBDIRS=$(PWD) modules

load:
	sudo insmod loader.ko

unload:
	sudo rmmod loader.ko


