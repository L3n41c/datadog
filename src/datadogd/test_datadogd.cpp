// src/datadogd/test_datadogd.cpp
// Unit tests for the datadogd executable (stub).

#include <datadog/version.h>
#include <gtest/gtest.h>

TEST(DatadogdTest, VersionIsNotEmpty) {
	EXPECT_FALSE(datadog::version.empty());
}

TEST(DatadogdTest, VersionHasContent) {
	EXPECT_GT(datadog::version.size(), 0U);
}
