// Unit tests for the log_receiver_syslog shared library (stub).

#include <gtest/gtest.h>
#include <string_view>

// Declare the exported symbol from the shared library.
extern "C" const std::string_view kVERSION;

TEST(LogReceiverSyslogTest, VersionIsNotEmpty) {
	EXPECT_FALSE(kVERSION.empty());
}

TEST(LogReceiverSyslogTest, VersionHasContent) {
	EXPECT_GT(kVERSION.size(), 0U);
}
