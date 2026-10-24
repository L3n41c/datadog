// Unit tests for the host_linux shared library (stub).

#include <gtest/gtest.h>
#include <string_view>

// Declare the exported symbol from the shared library.
extern "C" const std::string_view version;

TEST(HostLinuxTest, VersionIsNotEmpty) {
	EXPECT_FALSE(version.empty());
}

TEST(HostLinuxTest, VersionHasContent) {
	EXPECT_GT(version.size(), 0U);
}
