// Unit tests for the log_receiver_journald shared library (stub).

#include <gtest/gtest.h>
#include <string_view>

// Declare the exported symbol from the shared library.
extern "C" const std::string_view version;

TEST(LogReceiverJournaldTest, VersionIsNotEmpty) {
	EXPECT_FALSE(version.empty());
}

TEST(LogReceiverJournaldTest, VersionHasContent) {
	EXPECT_GT(version.size(), 0U);
}
