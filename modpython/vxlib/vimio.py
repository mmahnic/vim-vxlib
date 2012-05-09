#!/usr/bin/env python
# vim: set fileencoding=utf-8 sw=4 sts=4 ts=8 et :vim

import sys, stat, os
import locale
import time

STAT_ATTRS = []
for who in "USR", "GRP", "OTH":
    for what in "R", "W", "X":
        STAT_ATTRS.append( ("S_I" + what + who, what.lower()) )

def get_permissions(filename, stat_info):
    global STAT_ATTRS
    ftype = "-"
    link = ""
    sortord = 1

    mode = stat_info.st_mode
    if stat.S_ISDIR(mode):
        ftype="d"
        sortord = 0 # directories first
    elif stat.S_ISLNK(mode):
        ftype="l"
        link = os.readlink(filename)

    mode = stat.S_IMODE(mode)
    rxw = "".join([ att[1] if mode & getattr(stat, att[0]) else "-" for att in STAT_ATTRS ])
    return (ftype + rxw, link, sortord)

if sys.platform == "win32":
    def get_user_group(filename, stat_info):
        group = "-"
        try:
            import win32security as winsec
            sd = winsec.GetFileSecurity(filename, winsec.OWNER_SECURITY_INFORMATION)
            owner_sid = sd.GetSecurityDescriptorOwner()
            user, domain, type = winsec.LookupAccountSid(None, owner_sid)
        except:
            user = "-"
        return (user, group)
else:
    def get_user_group(filename, stat_info):
        try:
            import pwd
            user = "%s" % pwd.getpwuid(stat_info.st_uid)[0]
        except:
            user = "%s" % stat_info.st_uid
        try:
            import grp
            group = "%s" % grp.getgrgid(stat_info.st_gid)[0]
        except:
            group = "%s" % stat_info.st_gid
        return (user, group)

S_K = 1024.0
S_M = S_K * S_K
S_G = S_M * S_K
S_T = S_G * S_K
def get_hsize(stat_info):
    global S_K, S_M, S_G, S_T
    s = stat_info.st_size
    if s > S_T: return "%.1fT" % (s / S_T)
    if s > S_G: return "%.1fG" % (s / S_G)
    if s > S_M: return "%.1fM" % (s / S_M)
    if s > S_K: return "%.1fK" % (s / S_K)
    return "%4d" % s

def get_file_record(fullname):
    try: stat_info = os.lstat(fullname)
    except: return None

    perms, link, sortord = get_permissions(fullname, stat_info)
    nlink = "%d" % stat_info.st_nlink #formatting strings
    user, group = get_user_group(fullname, stat_info)
    size = get_hsize(stat_info)
    time_str = time.strftime("%Y-%m-%d %H:%M", time.localtime(stat_info.st_mtime))
    filename = os.path.basename(fullname)
    if link != "": filename = filename + " -> " + link

    rec = [perms, nlink, user, group, size, time_str, filename, sortord]
    return rec

def listdir(dirname):
    dirname = dirname.rstrip("/")
    if dirname == "": dirname = "/"
    files = os.listdir(dirname)

    recs = []
    for filename in files:
        fullname = os.path.join(dirname, filename)
        rec = get_file_record(fullname)
        if rec == None: continue
        recs.append(rec)

    try:
        thisdirrec = get_file_record(p1, os.path.basename(dirname))
        if thisdirrec != None:
            if thisdirrec[6] == "": thisdirrec = None
            else: thisdirrec[6] = "."
    except:
        thisdirrec = None

    if len(recs):
        sizes = [ 0 for r in recs[0] ][:7] # fields up to 'filename'
        for (i, a) in [(1, 1), (2, -1), (3, -1), (4, 1)]: # (index, alignment)
            sizes [i] = a * max((len(s[i]) for s in recs))
        fmts = []
        for s in sizes:
            if s != 0: fmts.append("%%%ds" % s)
            else: fmts.append("%s")
        fmt = " ".join(fmts) + "\n"

        locale.setlocale(locale.LC_ALL, '')
        def reccmp(a, b):
            if a[7] == b[7]: return locale.strcoll(a[6], b[6])
            return a[7] - b[7]
        recs.sort(reccmp)

    dotrec = get_file_record(os.path.dirname(dirname))
    if dotrec != None:
        dotrec[6] = ".."
        recs.insert(0, dotrec)
    dotrec = get_file_record(dirname)
    if dotrec != None:
        dotrec[6] = "."
        recs.insert(0, dotrec)

    for r in recs:
        sys.stdout.write(fmt % (r[0], r[1], r[2], r[3], r[4], r[5], r[6]))

if __name__ == "__main__":
    if sys.argv[1] == "ls":
        listdir(sys.argv[2])
