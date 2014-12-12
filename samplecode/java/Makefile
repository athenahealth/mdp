COMMONS-CODEC = ./commons-codec-1.9/commons-codec-1.9.jar
JCFLAGS = -J-Xmx48m -cp .:$(COMMONS-CODEC)
JC = javac

JAVAFLAGS = -Xmx48m -Xms48m -cp .:$(COMMONS-CODEC)
JAVA = java

TESTS = test/*.java
NAIVE = Naive.java
PACKAGE = com/athenahealth/api/*.java

.PHONY: all test clean

package:
	$(JC) $(JCFLAGS) $(PACKAGE)

default: package

naive:
	$(JC) $(JCFLAGS) $(NAIVE)

test:
	$(JC) $(JCFLAGS) $(TESTS)

all:
	$(JC) $(JCFLAGS) $(NAIVE) $(PACKAGE) $(TESTS)

run-naive:
	$(JAVA) $(JAVAFLAGS) Naive

run-test:
	$(JAVA) $(JAVAFLAGS) test/Testing

clean:
	$(RM) -v $(NAIVE:.java=.class) $(PACKAGE:.java=.class) $(TESTS:.java=.class)
