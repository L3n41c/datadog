// include/datadog/api.hpp
// Symbol-visibility macro for the public API of libdatadog_core.so (doc 02, doc 08).

#pragma once

#include <boost/config.hpp>

#ifdef DATADOG_CORE_BUILD
// Building libdatadog_core.so: export the symbol.
#define DATADOG_API BOOST_SYMBOL_EXPORT
#else
// Consuming libdatadog_core.so: the symbol is visible (default visibility).
#define DATADOG_API BOOST_SYMBOL_VISIBLE
#endif
