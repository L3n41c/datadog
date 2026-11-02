// Unit tests for the log_forwarder shared library (stub).

#include <gtest/gtest.h>
#include <string_view>

// Declare the exported symbol from the shared library.
extern "C" const std::string_view kVERSION;

TEST(LogForwarderTest, VersionIsNotEmpty) {
	EXPECT_FALSE(kVERSION.empty());
}

TEST(LogForwarderTest, VersionHasContent) {
	EXPECT_GT(kVERSION.size(), 0U);
}
