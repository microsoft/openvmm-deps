OBJ:=sample.o
TARGET:=libsample.a

# Take source files from the same directory as the Makefile, regardless of the
# current directory.
SOURCE:=$(dir $(realpath $(lastword $(MAKEFILE_LIST))))
vpath %.cpp $(SOURCE)

libsample.a: $(OBJ)
	ar rcs $@ $(OBJ)
