#ifndef UNION_H
#define UNION_H

enum types {
    TYPE_INT = 1,
    TYPE_BOOL,
    TYPE_REAL,
    TYPE_STRING,
    NO_TYPE
};

enum categories {
    TYPE_VAR = 1,
    TYPE_CONST,
    TYPE_FUNC,
    TYPE_PROC,
    TYPE_FOR_ARG,   // formal argument
    TYPE_ACT_ARG    // actual argumet
};

/* Union for values */
union unionValue {
    char sValue[256];   // string
    int iValue;         // int
    float fValue;       // float
    int bValue;         // bool
};

/* Info for non-terminals */ 
struct info {
    enum types type;
    enum categories category;
    union unionValue ntValue;
};

#endif