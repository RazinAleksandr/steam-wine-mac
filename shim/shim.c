/* dwmapi shim for steamwebhelper.exe.
 *
 * Wine on macOS cannot draw into a window that belongs to another process, so the
 * Steam UI stays black while Chromium runs a separate GPU process. This DLL is loaded
 * in place of dwmapi.dll (every call is forwarded to the real one, dwmapi_orig.dll)
 * and, before Chromium starts, puts --in-process-gpu on the main process command line.
 */
#include <windows.h>
#include <winternl.h>

static int ends_with_helper(const WCHAR *path)
{
    static const WCHAR name[] = L"steamwebhelper.exe";
    size_t n = lstrlenW(path), m = lstrlenW(name);
    return n >= m && !lstrcmpiW(path + n - m, name);
}

static int contains(const WCHAR *hay, const WCHAR *needle)
{
    size_t m = lstrlenW(needle);
    for (; *hay; hay++)
        if (!memcmp(hay, needle, m * sizeof(WCHAR))) return 1;
    return 0;
}

BOOL WINAPI DllMain(HINSTANCE inst, DWORD reason, LPVOID reserved)
{
    (void)reserved;
    if (reason != DLL_PROCESS_ATTACH) return TRUE;
    DisableThreadLibraryCalls(inst);

    WCHAR path[MAX_PATH];
    if (!GetModuleFileNameW(NULL, path, MAX_PATH) || !ends_with_helper(path)) return TRUE;

    /* Overwrite a harmless flag of equal or greater length in place, so the change is
     * visible through the PEB and through any pointer to the command line already saved. */
    static const WCHAR VICTIM[] = L"--enable-smooth-scrolling";
    static const WCHAR FLAG[]   = L"--in-process-gpu";
    WCHAR *bufs[2] = { GetCommandLineW(),
                       NtCurrentTeb()->ProcessEnvironmentBlock->ProcessParameters->CommandLine.Buffer };
    for (int i = 0; i < 2; i++) {
        WCHAR *p = bufs[i];
        if (!p || contains(p, L"--type=") || contains(p, FLAG)) continue;
        size_t vn = lstrlenW(VICTIM), fn = lstrlenW(FLAG);
        for (; *p; p++) {
            if (memcmp(p, VICTIM, vn * sizeof(WCHAR))) continue;
            memcpy(p, FLAG, fn * sizeof(WCHAR));
            for (size_t k = fn; k < vn; k++) p[k] = L' ';
            break;
        }
    }
    return TRUE;
}
