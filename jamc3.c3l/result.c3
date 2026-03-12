// JAM SDK - Result / Error types
// Faults returned by SDK operations.
module jam::result;

faultdef
    STORAGE_KV_READ,
    STORAGE_KV_WRITE,
    INSUFFICIENT_BALANCE,
    STORAGE_KV_DELETE,
    NO_KEY,
    NO_DATA,
    NO_OUT,
    UNREACHABLE,
    UNDECODABLE,
    TOO_BIG,
    TRAILING_DATA,
    ALLOC_FAILURE,
    HOST_ERROR;
