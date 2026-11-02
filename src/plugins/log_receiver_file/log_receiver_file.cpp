// log_receiver_file — shared library plugin (stub).

#include <boost/config.hpp>
#include <datadog/version.h>
#include <string_view>

/// Global version variable exported from this shared library.
extern "C" BOOST_SYMBOL_EXPORT const std::string_view kVERSION = datadog::kVERSION;
