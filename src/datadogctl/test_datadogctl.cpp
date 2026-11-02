// src/datadogctl/test_datadogctl.cpp
// Unit tests for the datadogctl executable (stub).

#include <datadog/version.h>
#include <gtest/gtest.h>

TEST(DatadogctlTest, VersionIsNotEmpty) {
	EXPECT_FALSE(datadog::kVERSION.empty());
}

TEST(DatadogctlTest, VersionHasContent) {
	EXPECT_GT(datadog::kVERSION.size(), 0U);
}
