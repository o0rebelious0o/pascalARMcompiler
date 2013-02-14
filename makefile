compiler: cwy.o cwl.o token.o
	g++ -o CW1 cwy.o cwl.o token.o
	(rm cw[yl].cpp *.o *.[yls]~ *.pas~ *.output cwy.h)
		
token.o: token.cpp
	g++ -c -w token.cpp

cwy.o: cwy.cpp cwy.h
	g++ -c -w cwy.cpp

cwy.cpp: cwy.y cwy.h
	bison --report=state -v cwy.y
	./gramdiag cwy.output > cwy.report
	mv cwy.tab.c cwy.cpp

cwy.h: cwy.y
	bison -d cwy.y 
	rm cwy.tab.c 
	mv cwy.tab.h cwy.h

cwl.o: cwl.cpp
	g++ -c -w cwl.cpp

cwl.cpp: cwl.l
	flex -t cwl.l > cwl.cpp

clean:
	(rm cw[yl].cpp *.o *.[yls]~ *.pas~ *.output *.report cwy.h)
