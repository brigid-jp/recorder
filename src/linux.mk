CPPFLAGS =
CXXFLAGS = -Wall -W -O2 -std=c++11 -fPIC

OBJS = server.o
TARGET = server

all: $(TARGET)

clean:
	rm -f $(TARGET) $(OBJS)

$(TARGET): $(OBJS)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ $^

.cpp.o:
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -c $<
