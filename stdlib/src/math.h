#pragma once
#include "builtin/builtin.h"
#include "builtin/env.h"
#include "rts/rts.h"
struct mathQ_RealFuns;
typedef struct mathQ_RealFuns *mathQ_RealFuns;
struct mathQ_RealFunsG_class {
    char *$GCINFO;
    B_int $class_id;
    $SuperG_class $superclass;
    B_NoneType (*__init__) (mathQ_RealFuns);
    B_NoneType (*__serialize__) (mathQ_RealFuns, $Serial$state);
    mathQ_RealFuns (*__deserialize__) (mathQ_RealFuns, $Serial$state);
    B_bool (*__bool__)(mathQ_RealFuns);
    B_str (*__str__)(mathQ_RealFuns);
    B_str (*__repr__)(mathQ_RealFuns);
    $WORD (*sqrt) (mathQ_RealFuns, $WORD);
    $WORD (*exp) (mathQ_RealFuns, $WORD);
    $WORD (*log) (mathQ_RealFuns, $WORD);
    $WORD (*sin) (mathQ_RealFuns, $WORD);
    $WORD (*cos) (mathQ_RealFuns, $WORD);
    $WORD (*tan) (mathQ_RealFuns, $WORD);
    $WORD (*asin) (mathQ_RealFuns, $WORD);
    $WORD (*acos) (mathQ_RealFuns, $WORD);
    $WORD (*atan) (mathQ_RealFuns, $WORD);
    $WORD (*sinh) (mathQ_RealFuns, $WORD);
    $WORD (*cosh) (mathQ_RealFuns, $WORD);
    $WORD (*tanh) (mathQ_RealFuns, $WORD);
    $WORD (*asinh) (mathQ_RealFuns, $WORD);
    $WORD (*acosh) (mathQ_RealFuns, $WORD);
    $WORD (*atanh) (mathQ_RealFuns, $WORD);
};
struct mathQ_RealFuns {
    struct mathQ_RealFunsG_class *$class;
};
extern struct mathQ_RealFunsG_class mathQ_RealFunsG_methods;
mathQ_RealFuns mathQ_RealFunsG_new();
struct mathQ_RealFunsD_float;
typedef struct mathQ_RealFunsD_float *mathQ_RealFunsD_float;
struct mathQ_RealFunsD_floatG_class {
    char *$GCINFO;
    B_int $class_id;
    $SuperG_class $superclass;
    B_NoneType (*__init__) (mathQ_RealFunsD_float);
    B_NoneType (*__serialize__) (mathQ_RealFunsD_float, $Serial$state);
    mathQ_RealFunsD_float (*__deserialize__) (mathQ_RealFunsD_float, $Serial$state);
    B_bool (*__bool__)(mathQ_RealFunsD_float);
    B_str (*__str__)(mathQ_RealFunsD_float);
    B_str (*__repr__)(mathQ_RealFunsD_float);
    B_float (*sqrt) (mathQ_RealFunsD_float, B_float);
    B_float (*exp) (mathQ_RealFunsD_float, B_float);
    B_float (*log) (mathQ_RealFunsD_float, B_float);
    B_float (*sin) (mathQ_RealFunsD_float, B_float);
    B_float (*cos) (mathQ_RealFunsD_float, B_float);
    B_float (*tan) (mathQ_RealFunsD_float, B_float);
    B_float (*asin) (mathQ_RealFunsD_float, B_float);
    B_float (*acos) (mathQ_RealFunsD_float, B_float);
    B_float (*atan) (mathQ_RealFunsD_float, B_float);
    B_float (*sinh) (mathQ_RealFunsD_float, B_float);
    B_float (*cosh) (mathQ_RealFunsD_float, B_float);
    B_float (*tanh) (mathQ_RealFunsD_float, B_float);
    B_float (*asinh) (mathQ_RealFunsD_float, B_float);
    B_float (*acosh) (mathQ_RealFunsD_float, B_float);
    B_float (*atanh) (mathQ_RealFunsD_float, B_float);
};
struct mathQ_RealFunsD_float {
    struct mathQ_RealFunsD_floatG_class *$class;
};
extern struct mathQ_RealFunsD_floatG_class mathQ_RealFunsD_floatG_methods;
mathQ_RealFunsD_float mathQ_RealFunsD_floatG_new();
$WORD mathQ_sqrt (mathQ_RealFuns, $WORD);
$WORD mathQ_exp (mathQ_RealFuns, $WORD);
$WORD mathQ_log (mathQ_RealFuns, $WORD);
$WORD mathQ_sin (mathQ_RealFuns, $WORD);
$WORD mathQ_cos (mathQ_RealFuns, $WORD);
$WORD mathQ_tan (mathQ_RealFuns, $WORD);
$WORD mathQ_asin (mathQ_RealFuns, $WORD);
$WORD mathQ_acos (mathQ_RealFuns, $WORD);
$WORD mathQ_atan (mathQ_RealFuns, $WORD);
$WORD mathQ_sinh (mathQ_RealFuns, $WORD);
$WORD mathQ_cosh (mathQ_RealFuns, $WORD);
$WORD mathQ_tanh (mathQ_RealFuns, $WORD);
$WORD mathQ_asinh (mathQ_RealFuns, $WORD);
$WORD mathQ_acosh (mathQ_RealFuns, $WORD);
$WORD mathQ_atanh (mathQ_RealFuns, $WORD);
void mathQ___init__ ();
