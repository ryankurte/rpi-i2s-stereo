# Helper makefile to build components

card:
    cd asoc_simple_card && make

loader:
    cd loader && make

insmod:
	sudo insmod asoc_simple_card/asoc_simple_card.ko 
	sudo insmod loader/loader.ko
