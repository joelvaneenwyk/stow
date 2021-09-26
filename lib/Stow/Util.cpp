#if defined(WIN32)
    #define WINVER 0x600
    #define _WIN32_WINNT 0x0600

    #include <windows.h>
#endif

#define SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE 0x2

int my_CreateSymbolicLink(char* From, char* To, int isDir) {
#if defined(WIN32)
    return CreateSymbolicLinkW(
        (LPCWSTR) From, (LPCWSTR) To,
        isDir | SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE);
#else
    return 0;
#endif
}

int my_CreateHardLink(char* From, char* To) {
#if defined(WIN32)
    return CreateHardLinkW( (LPCWSTR) From,  (LPCWSTR) To, NULL);
#else
    return 0;
#endif
}

#if defined(WIN32)
//# Not found in strawberry perl Windows headers

typedef struct _REPARSE_DATA_BUFFER {
    ULONG  ReparseTag;
    USHORT ReparseDataLength;
    USHORT Reserved;
    union {
        struct {
            USHORT SubstituteNameOffset;
            USHORT SubstituteNameLength;
            USHORT PrintNameOffset;
            USHORT PrintNameLength;
            ULONG  Flags;
            WCHAR  PathBuffer[1];
        } SymbolicLinkReparseBuffer;

        struct {
            USHORT SubstituteNameOffset;
            USHORT SubstituteNameLength;
            USHORT PrintNameOffset;
            USHORT PrintNameLength;
            WCHAR  PathBuffer[1];
        } MountPointReparseBuffer;

        struct {
            UCHAR DataBuffer[4096];
        } GenericReparseBuffer;
    };
} REPARSE_DATA_BUFFER, *PREPARSE_DATA_BUFFER;
#endif

int my_ReadLink( SV* svlink, SV* target ) {
#if defined(WIN32)
    HANDLE h;
    DWORD len;
    REPARSE_DATA_BUFFER rdb;
    BOOL ok;

    h = CreateFileW(
            (LPCWSTR) SvPV(svlink, PL_na),
            FILE_READ_ATTRIBUTES,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            NULL,
            OPEN_EXISTING,
            FILE_FLAG_BACKUP_SEMANTICS | FILE_ATTRIBUTE_REPARSE_POINT | FILE_FLAG_OPEN_REPARSE_POINT,
            NULL
    );
    if( h == INVALID_HANDLE_VALUE ) { //# Probably File Not Found or similar
        return 0; //# Hence it's not a Symlink
    }

    ok = DeviceIoControl (
        h,
        0x900a8, //# FSCTL_GET_REPARSE_POINT
        NULL,
        0,
        &rdb,
        0x1000, //# Max size of RDB apparently
        &len,
        NULL);

    CloseHandle( h );
    if( !ok ) {
        //# SMELL?: Quite unexpected, maybe raise exception or return error - somehow?
        return 0;
    }

    if( rdb.ReparseTag == IO_REPARSE_TAG_SYMLINK ) {
        char *buf = (char *) rdb.SymbolicLinkReparseBuffer.PathBuffer;
        int off = (int) rdb.SymbolicLinkReparseBuffer.PrintNameOffset;
        int len = (int) rdb.SymbolicLinkReparseBuffer.PrintNameLength;

        sv_setpvn( target, buf + off, len );
        return 1; //# Success
    }
    else if( rdb.ReparseTag == IO_REPARSE_TAG_MOUNT_POINT ) { //# Just for reference, but we don't care about this case
        return 0;
    }
#endif

    //# Not a reparse point at all
    return 0;
}
