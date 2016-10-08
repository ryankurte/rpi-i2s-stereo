# Sound driver makefile

obj-m := asoc_simple_card.o
KDIR := /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)
   
build:
	$(MAKE) -C $(KDIR) SUBDIRS=$(PWD) modules

load:
	sudo insmod asoc_simple_card.ko

unload:
	sudo rmmod asoc_simple_card.ko


