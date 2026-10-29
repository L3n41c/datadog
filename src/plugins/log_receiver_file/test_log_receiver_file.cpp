// Unit tests for the log_receiver_file shared library (stub).

#include <gtest/gtest.h>
#include <string_view>

// Declare the exported symbol from the shared library.
extern "C" const std::string_view kVERSION;

TEST(LogReceiverFileTest, VersionIsNotEmpty) {
	EXPECT_FALSE(kVERSION.empty());
}

TEST(LogReceiverFileTest, VersionHasContent) {
	EXPECT_GT(kVERSION.size(), 0U);
}
