#!/usr/bin/env python
# -*- coding: utf-8 -*-

def _isLang(s, os, oe, *args):
    if len(s) == 0:
        return False

    if len(args) == 0:
        for c in s:
            if ord(c) not in range(os, oe):
                return False 
    
    elif len(args) == 2:
        for c in s:
            if ord(c) not in range(os, oe) and ord(c) not in range(args[0], args[1]):
                return False

    return True


def isCyrillic(s):
    return _isLang(s, 1024, 1274)


def isGreek(s):
    return _isLang(s, 880, 1280)


def isArmenian(s):
    return _isLang(s, 1328, 1424)


def isHebrew(s):
    return _isLang(s, 1424, 1536)


def isArabic(s):
    return _isLang(s, 1536, 1792)


def isSyriac(s):
    return _isLang(s, 1792, 1872)


def isThaan(s):
    return _isLang(s, 1920, 1984)


def isDevanagari(s):
    return _isLang(s, 2304, 2432)


def isBengali(s):
    return _isLang(s, 2432, 2560)


def isGurmukhi(s):
    return _isLang(s, 2560, 2688)


def isGujarati(s):
    return _isLang(s, 2688, 2816)


def isOriya(s):
    return _isLang(s, 2816, 2944)


def isTamil(s):
    return _isLang(s, 2944, 3072)


def isTelugu(s):
    return _isLang(s, 3072, 3200)


def isKannada(s):
    return _isLang(s, 3200, 3328)


def isMalayalam(s):
    return _isLang(s, 3328, 3456)


def isSinhala(s):
    return _isLang(s, 3456, 3584)


def isThai(s):
    return _isLang(s, 3584, 3712)


def isLao(s):
    return _isLang(s, 3712, 3840)


def isTibetan(s):
    return _isLang(s, 3840, 4096)


def isMyanmar(s):
    return _isLang(s, 4096, 4256)


def isGeorgian(s):
    return _isLang(s, 4256, 4352)


def isHangulJamo(s):
    return _isLang(s, 4352, 4608)


def isCherokee(s):
    return _isLang(s, 5024, 5120)


def isUCAS(s):
    "Unified Canadian Aboriginal Syllabics"
    return _isLang(s, 5120, 5760)


def isOgham(s):
    return _isLang(s, 5760, 5792)


def isRunic(s):
    return _isLang(s, 5792, 5888)


def isKhmer(s):
    return _isLang(s, 6016, 6144)


def isMongolian(s):
    return _isLang(s, 6144, 6320)


def isLatin(s):
    return _isLang(s, 65, 866)

