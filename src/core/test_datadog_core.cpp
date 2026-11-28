// src/core/test_datadog_core.cpp
// Unit tests for libdatadog_core.so.

#include <datadog/core.hpp>
#include <datadog/version.h>
#include <gtest/gtest.h>

TEST(DatadogCoreTest, CoreVersionIsNotEmpty) { EXPECT_FALSE(datadog::core_version().empty()); }

TEST(DatadogCoreTest, CoreVersionMatchesProjectVersion) {
	EXPECT_EQ(datadog::core_version(), datadog::kVERSION);
}
