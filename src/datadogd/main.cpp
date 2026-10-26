// src/datadogd/main.cpp
// datadogd — main daemon executable (stub).

#include <datadog/version.h>
#include <iostream>

int main() {
	std::cout << "Hello world!\n" << datadog::kVERSION;
	return 0;
}
