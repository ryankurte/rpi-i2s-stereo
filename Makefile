# Helper makefile to build components

card:
    cd driver && make

loader:
    cd loader && make

insmod:
	sudo insmod driver/asoc_simple_card.ko 
	sudo insmod loader/loader.ko
