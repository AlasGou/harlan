
ALL_TEST_SRC = $(filter-out %~ %\#, $(wildcard test/*))
XFAIL_TEST_SRC = $(shell grep -l xfail $(ALL_TEST_SRC))

RUN_TEST_SRC = $(filter-out $(XFAIL_TEST_SRC), $(ALL_TEST_SRC))

CXXFLAGS := -g -O2

# Set up the flags to handle OpenCL
ifeq ($(shell uname), Darwin)
CXXFLAGS := $(CXXFLAGS) -framework OpenCL
else
ifeq ($(shell uname), Linux)
# This should work on 64-bit Gentoo with NVIDIA GPUs at least. YMMV.
CXXFLAGS := $(CXXFLAGS) -I/opt/cuda/include -lOpenCL
else
$(error Your operating system is not yet supported.)
endif
endif

# Use clang if available, because it has better error messages.
#ifneq (,`which clang++`)
CXX = clang++
#else
#CXX = g++
#endif

# Invokes the harlan compiler. The first argument is the name of the
# source file, the second is the name of the output file.
HC = ./harlanc $(1) | $(CXX) test.bin/cl++.o $(CXXFLAGS) -x c++ -o $(2) -

TEST_EXE_NAME = $(patsubst test/%, test.bin/%.bin, $(1))

TEST_OUT_NAME = $(patsubst test/%, test.bin/%.out, $(1))

COMPILE_TEST = $(call HC, $(1), $(call TEST_EXE_NAME, $(1)))

RUN_TEST = $(1)

.phony: check
check : test.bin test.bin/cl++.o cl++.h cl++.cpp \
		$(call TEST_OUT_NAME, $(RUN_TEST_SRC))
	@echo All tests succeeded.

test.bin:
	mkdir -p test.bin

test.bin/cl++.o : test.bin cl++.h cl++.cpp
	$(CXX) $(CXXFLAGS) -c cl++.cpp -o test.bin/cl++.o

.phony: clean
clean:
	rm -rf test.bin *.dSYM

test.bin/%.out : test.bin/%.bin
	@echo Running $<
	@$(call RUN_TEST, $(call TEST_EXE_NAME, $<)) > $@

.precious : $(call TEST_EXE_NAME, $(RUN_TEST_SRC))
test.bin/%.bin : test/% test.bin/cl++.o cl++.h cl++.cpp vectors.h
	@echo Compiling $<
	@$(call COMPILE_TEST, $<)
