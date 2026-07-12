#!/usr/bin/env python3
"""Post-process a Godot macOS export zip: space-free rename + ad-hoc code sign.

Two mandatory transforms happen here, in this order:

  (A) RENAME so the bundle has NO space in its name.
      The owner hit macOS quarantine/Gatekeeper confusion caused by the space in
      "Project Whisper.app" (the space breaks naive `xattr -dr com.apple.quarantine`
      one-liners and shell tab-completion). We rewrite every path + the Info.plist
      so the shipped bundle is "ProjectWhisper.app" with a space-free executable.

        * "Project Whisper.app/"                       -> "ProjectWhisper.app/"
        * ".../Contents/MacOS/Project Whisper"         -> ".../Contents/MacOS/ProjectWhisper"
        * ".../Contents/Resources/Project Whisper.pck" -> ".../Contents/Resources/ProjectWhisper.pck"
              (MUST match the executable name — Godot locates its data pck by the
               bundle/executable name; leaving a space here => "Couldn't load project data".)
      And in Contents/Info.plist:
        * CFBundleExecutable  -> ProjectWhisper
        * CFBundleName        -> ProjectWhisper
        (CFBundleDisplayName is left as the pretty "Project Whisper" — that's only the
         Finder label and does not affect launch or the pck lookup.)

  (B) AD-HOC CODE SIGN with rcodesign (indygreg/apple-platform-rs).
      Apple Silicon Gatekeeper blocks the raw Godot export as "damaged" (the Godot
      linker leaves only a LINKER_SIGNED ad-hoc signature and no bundle CodeResources).
      Signing the bundle again with rcodesign produces a proper ADHOC CodeDirectory
      over BOTH universal slices plus a Contents/_CodeSignature/CodeResources sealing
      the bundle. With that, the owner's right-click -> Open (first launch only) works
      without any `xattr` dance. rcodesign runs on Linux arm64 (Apple codesign cannot),
      so signing happens on the build host. Ad-hoc == no certificate argument.

      The signed executable is left UNTOUCHED apart from its embedded signature; the
      Resources/*.pck (the whole game) is never modified — so the packaged game stays
      byte-identical to the unsigned build.

The build MUST NOT emit an unsigned zip: if rcodesign is missing or signing/verification
fails, this script aborts with a clear error and writes no output.

Usage:
    postprocess_macos_zip.py <in.zip> [<out.zip>]
If <out.zip> is omitted the input is rewritten in place (via a temp file).

Environment:
    RCODESIGN  path to the rcodesign binary (default: <this dir>/rcodesign, then $PATH).
"""

import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import zipfile

OLD = "Project Whisper"
NEW = "ProjectWhisper"

_HERE = os.path.dirname(os.path.abspath(__file__))

# Custom app icon. The Godot export ships Godot's DEFAULT placeholder .icns
# (largest real bitmap 256px, no Retina 512/1024). We overwrite the bundle's
# Contents/Resources/icon.icns with the project icon rendered by
# project-whisper/tools/make_app_icon.py. The Godot Info.plist already declares
# CFBundleIconFile=icon.icns, so swapping the file's bytes is all that's needed —
# no plist edit, no rename. If the custom icon is absent the build proceeds with
# Godot's default (icon is cosmetic; it must never block a release).
# Two identical copies of this script exist and must stay in sync:
#   * <repo-parent>/tools/postprocess_macos_zip.py   (shared; build_exports.sh calls
#     it as POSTPROC=$REPO/../tools/...) — here _HERE/.. is <repo-parent>.
#   * <repo>/tools/postprocess_macos_zip.py           (vendored INTO the repo for
#     version control) — here _HERE/.. is the repo root.
# So we probe several candidate locations rather than one fixed relative path, and
# also honor $PW_APP_ICNS. Icon is cosmetic: if none resolve, the build proceeds.
_ICON_REL = os.path.join("assets-src", "appicon", "ProjectWhisper.icns")
_ICON_CANDIDATES = [
    os.path.join(_HERE, "..", "project-whisper", _ICON_REL),  # shared tools/ layout
    os.path.join(_HERE, "..", _ICON_REL),                      # vendored repo tools/ layout
    os.path.join(_HERE, _ICON_REL),                            # icon beside the script
]


def _load_custom_icon():
    """Return custom .icns bytes if present and valid, else None."""
    override = os.environ.get("PW_APP_ICNS")
    candidates = ([override] if override else []) + _ICON_CANDIDATES
    for cand in candidates:
        path = os.path.abspath(cand)
        if not os.path.isfile(path):
            continue
        with open(path, "rb") as f:
            data = f.read()
        if data[:4] != b"icns":
            print("WARN custom icon %s is not an icns (ignored)" % path)
            continue
        print("using custom app icon: %s (%d bytes)" % (path, len(data)))
        return data
    return None


def _rename_path(name: str) -> str:
    # Rename the .app dir, the MacOS/<exe> and the Resources/<name>.pck. We only
    # touch the space-containing segments that are the bundle dir, the executable
    # basename, and the pck basename — matching "Project Whisper" as a path token.
    name = name.replace(OLD + ".app", NEW + ".app")
    name = name.replace("/MacOS/" + OLD, "/MacOS/" + NEW)
    name = name.replace("/Resources/" + OLD + ".pck", "/Resources/" + NEW + ".pck")
    return name


def _patch_plist(data: bytes) -> bytes:
    text = data.decode("utf-8")
    # Only CFBundleExecutable and CFBundleName -> space-free. Use a targeted regex
    # keyed on the <key> so we never touch CFBundleDisplayName or unrelated strings.
    for key in ("CFBundleExecutable", "CFBundleName"):
        text = re.sub(
            r"(<key>%s</key>\s*<string>)[^<]*(</string>)" % re.escape(key),
            r"\g<1>" + NEW + r"\g<2>",
            text,
        )
    return text.encode("utf-8")


def _find_rcodesign() -> str:
    """Locate the rcodesign binary; abort clearly if not found/usable."""
    cand = os.environ.get("RCODESIGN")
    candidates = [cand] if cand else []
    candidates.append(os.path.join(_HERE, "rcodesign"))
    which = shutil.which("rcodesign")
    if which:
        candidates.append(which)
    for c in candidates:
        if c and os.path.isfile(c) and os.access(c, os.X_OK):
            try:
                out = subprocess.run(
                    [c, "--version"], capture_output=True, text=True, check=True
                )
            except (OSError, subprocess.CalledProcessError) as e:
                raise SystemExit("rcodesign at %s not runnable: %s" % (c, e))
            print("using rcodesign: %s (%s)" % (c, out.stdout.strip()))
            return c
    raise SystemExit(
        "sign FAILED — rcodesign not found (looked at $RCODESIGN, %s, and $PATH). "
        "Refusing to ship an unsigned macOS zip." % os.path.join(_HERE, "rcodesign")
    )


def _extract_bundle(zip_path: str, dest: str) -> str:
    """Extract the (already-renamed) zip to dest, preserving unix modes.

    Returns the path to the single top-level .app bundle.
    """
    app_dir = None
    with zipfile.ZipFile(zip_path, "r") as z:
        for info in z.infolist():
            p = z.extract(info, dest)
            mode = (info.external_attr >> 16) & 0xFFFF
            if mode and not info.is_dir():
                os.chmod(p, mode)
            top = info.filename.split("/", 1)[0]
            if top.endswith(".app"):
                app_dir = os.path.join(dest, top)
    if app_dir is None or not os.path.isdir(app_dir):
        raise SystemExit("sign FAILED — no .app bundle found in %s" % zip_path)
    return app_dir


def _sign_and_verify(rcodesign: str, app_dir: str) -> None:
    """Ad-hoc sign the bundle in place, then verify the ADHOC signature is real.

    Ad-hoc == invoke `rcodesign sign` with NO certificate source. We verify by
    inspecting the embedded signature of the main Mach-O: every universal slice
    must carry an ADHOC CodeDirectory, and a bundle CodeResources must exist.
    rcodesign's own `verify` subcommand self-reports as buggy for ad-hoc (it
    expects a CMS cert that ad-hoc signatures deliberately omit), so we do not
    rely on it.
    """
    print("== rcodesign sign (ad-hoc) ==")
    subprocess.run([rcodesign, "sign", app_dir], check=True)

    # Bundle-level seal must exist.
    code_resources = os.path.join(app_dir, "Contents", "_CodeSignature", "CodeResources")
    if not os.path.isfile(code_resources):
        raise SystemExit(
            "sign FAILED — no Contents/_CodeSignature/CodeResources after signing"
        )

    exe = os.path.join(app_dir, "Contents", "MacOS", NEW)
    if not os.path.isfile(exe):
        raise SystemExit("sign FAILED — signed executable %s missing" % exe)

    print("== rcodesign verify (signature inspection) ==")
    info = subprocess.run(
        [rcodesign, "print-signature-info", exe],
        capture_output=True, text=True, check=True,
    ).stdout

    # Each universal slice reports a `flags:` line; all must be ADHOC and none may
    # be an unsigned slice. Godot's linker leaves ADHOC|LINKER_SIGNED; after our
    # re-sign the slices must be plain ADHOC (a proper, non-linker CodeDirectory).
    flag_lines = [ln.strip() for ln in info.splitlines() if ln.strip().startswith("flags:")]
    if not flag_lines:
        raise SystemExit("sign FAILED — no signature flags found in %s" % exe)
    for ln in flag_lines:
        if "ADHOC" not in ln:
            raise SystemExit("sign FAILED — non-ad-hoc slice after signing: %s" % ln)
        if "LINKER_SIGNED" in ln:
            raise SystemExit(
                "sign FAILED — slice still only LINKER_SIGNED (re-sign did not take): %s" % ln
            )
    print("verify OK: %d slice(s) ADHOC-signed, CodeResources sealed" % len(flag_lines))


def _rezip_bundle(app_dir: str, out_zip: str) -> None:
    """Zip the signed bundle back up, preserving unix modes (esp. the 0755 exe)."""
    root = os.path.dirname(app_dir)
    tmp_fd, tmp_path = tempfile.mkstemp(suffix=".zip")
    os.close(tmp_fd)
    with zipfile.ZipFile(tmp_path, "w", zipfile.ZIP_DEFLATED) as z:
        for dirpath, dirnames, filenames in os.walk(app_dir):
            dirnames.sort()
            for fn in sorted(filenames):
                full = os.path.join(dirpath, fn)
                arc = os.path.relpath(full, root)
                st = os.lstat(full)
                if stat.S_ISLNK(st.st_mode):
                    # Preserve symlinks as symlink entries.
                    zi = zipfile.ZipInfo(arc)
                    zi.create_system = 3  # unix
                    zi.external_attr = (st.st_mode & 0xFFFF) << 16
                    z.writestr(zi, os.readlink(full))
                    continue
                zi = zipfile.ZipInfo.from_file(full, arc)
                zi.compress_type = zipfile.ZIP_DEFLATED
                zi.external_attr = (st.st_mode & 0xFFFF) << 16
                with open(full, "rb") as fh:
                    z.writestr(zi, fh.read())
    shutil.move(tmp_path, out_zip)


def process(in_zip: str, out_zip: str) -> None:
    # rcodesign must be available BEFORE we do any work — fail fast, never ship
    # an unsigned zip.
    rcodesign = _find_rcodesign()
    custom_icon = _load_custom_icon()

    src = zipfile.ZipFile(in_zip, "r")
    tmp_fd, tmp_path = tempfile.mkstemp(suffix=".zip")
    os.close(tmp_fd)
    renamed = 0
    icon_swapped = False
    with zipfile.ZipFile(tmp_path, "w", zipfile.ZIP_DEFLATED) as dst:
        for item in src.infolist():
            data = src.read(item.filename)
            new_name = _rename_path(item.filename)
            if new_name != item.filename:
                renamed += 1
            if item.filename.endswith("/Contents/Info.plist"):
                data = _patch_plist(data)
            if custom_icon is not None and item.filename.endswith(
                "/Contents/Resources/icon.icns"
            ):
                data = custom_icon
                icon_swapped = True
            # Preserve the entry's metadata (esp. the unix mode / exec bit).
            new_info = zipfile.ZipInfo(new_name, date_time=item.date_time)
            new_info.compress_type = zipfile.ZIP_DEFLATED
            new_info.external_attr = item.external_attr
            new_info.internal_attr = item.internal_attr
            new_info.create_system = item.create_system
            dst.writestr(new_info, data)
    src.close()

    if custom_icon is not None and not icon_swapped:
        print("WARN custom icon present but no Contents/Resources/icon.icns entry "
              "found in the export — icon not swapped")

    # Verify the rename result: no space-containing bundle/exe/pck paths remain,
    # and the plist keys are patched.
    with zipfile.ZipFile(tmp_path, "r") as chk:
        names = chk.namelist()
        bad = [n for n in names if (OLD + ".app") in n
               or ("/MacOS/" + OLD) in n
               or ("/Resources/" + OLD + ".pck") in n]
        if bad:
            raise SystemExit("postprocess FAILED — space-named entries remain: %s" % bad)
        plist_name = next((n for n in names if n.endswith("/Contents/Info.plist")), None)
        if plist_name is not None:
            pl = chk.read(plist_name).decode("utf-8")
            for key in ("CFBundleExecutable", "CFBundleName"):
                m = re.search(r"<key>%s</key>\s*<string>([^<]*)</string>" % re.escape(key), pl)
                if not m or m.group(1) != NEW:
                    raise SystemExit("postprocess FAILED — %s not patched to %s" % (key, NEW))
        exe = next((n for n in names if ("/MacOS/" + NEW) in n and not n.endswith("/")), None)
        pck = next((n for n in names if ("/Resources/" + NEW + ".pck") in n), None)
        if exe is None:
            raise SystemExit("postprocess FAILED — no renamed executable entry found")
        if pck is None:
            raise SystemExit("postprocess FAILED — no renamed .pck entry found")

    # --- Sign: extract the renamed bundle, ad-hoc sign it, re-zip. This happens
    # BEFORE the final zip is written, so a signing failure never yields output. ---
    workdir = tempfile.mkdtemp(prefix="pw_macos_sign_")
    try:
        app_dir = _extract_bundle(tmp_path, workdir)
        _sign_and_verify(rcodesign, app_dir)
        _rezip_bundle(app_dir, out_zip)
    finally:
        shutil.rmtree(workdir, ignore_errors=True)
        if os.path.exists(tmp_path):
            os.remove(tmp_path)

    print("postprocess OK: %s -> %s (%d entries renamed, ad-hoc signed)"
          % (in_zip, out_zip, renamed))


def main(argv) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    in_zip = argv[1]
    out_zip = argv[2] if len(argv) > 2 else in_zip
    if not os.path.isfile(in_zip):
        raise SystemExit("input zip not found: %s" % in_zip)
    process(in_zip, out_zip)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
