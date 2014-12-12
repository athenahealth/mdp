REFS = /reference:System.Json

COMPILER = mcs
CFLAGS = 

TEST = Testing.cs
NAIVE = Naive.cs
PACKAGE = AthenahealthAPI.cs

.PHONY: all test clean

default: all

naive:
	$(COMPILER) $(CFLAGS) $(REFS) $(NAIVE) -out:$(NAIVE:.cs=.exe)

test: 
	$(COMPILER) $(CFLAGS) $(REFS) $(TEST) $(PACKAGE) -out:$(TEST:.cs=.exe)

all: naive test
