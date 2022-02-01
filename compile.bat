rgbasm -L -o %~n1.o %~n1.asm
rgblink -o %~n1.gb %~n1.o
rgbfix -v -p 0xFF %~n1.gb
rgblink -n %~n1.sym %~n1.o
