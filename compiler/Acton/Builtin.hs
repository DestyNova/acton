module Acton.Builtin where

import Utils
import Acton.Syntax
    
selfKW                              = name "__self__"

initKW                              = name "__init__"
fromiterKW                          = name "__fromiter__"
fromatomKW                          = name "__fromatom__"
lenKW                               = name "__len__"
enterKW                             = name "__enter__"
exitKW                              = name "__exit__"
iterKW                              = name "__iter__"
nextKW                              = name "__next__"
containsKW                          = name "__contains__"
containsnotKW                       = name "__containsnot__"
getitemKW                           = name "__getitem__"
setitemKW                           = name "__setitem__"
delitemKW                           = name "__delitem__"
getsliceKW                          = name "__getslice__"
setsliceKW                          = name "__setslice__"
delsliceKW                          = name "__delslice__"
boolKW                              = name "__bool__"

methKWs                             = [initKW,enterKW,exitKW,iterKW,nextKW,containsKW,containsnotKW,getitemKW,setitemKW,getsliceKW,setsliceKW,boolKW]

iaddKW                              = name "__iadd__"
isubKW                              = name "__isub__"
imulKW                              = name "__imul__"
ipowKW                              = name "__ipow__"
itruedivKW                          = name "__itruediv__"
imodKW                              = name "__imod__"
ifloordivKW                         = name "__ifloordiv__"
ilshiftKW                           = name "__ilshift__"
irshiftKW                           = name "__irshift__"
iorKW                               = name "__ior__"
ixorKW                              = name "__ixor__"
iandKW                              = name "__iand__"
imatmulKW                           = name "__imatmul__"

iopKWs                              = [iaddKW,isubKW,imulKW,ipowKW,itruedivKW,imodKW,ifloordivKW,ilshiftKW,irshiftKW,iorKW,ixorKW,iandKW,imatmulKW]

addKW                               = name "__add__"
subKW                               = name "__sub__"
mulKW                               = name "__mul__"
powKW                               = name "__pow__"
truedivKW                           = name "__truediv__"
modKW                               = name "__mod__"
floordivKW                          = name "__floordiv__"
lshiftKW                            = name "__lshift__"
rshiftKW                            = name "__rshift__"
orKW                                = name "__or__"
xorKW                               = name "__xor__"
andKW                               = name "__and__"
matmulKW                            = name "__matmul__"

binopKWs                            = [addKW,subKW,mulKW,powKW,truedivKW,modKW,floordivKW,lshiftKW,rshiftKW,orKW,xorKW,andKW,matmulKW]

posKW                               = name "__pos__"
negKW                               = name "__neg__"
invertKW                            = name "__invert__"

unopKWs                             = [posKW,negKW,invertKW]

eqKW                                = name "__eq__"
neKW                                = name "__ne__"
ltKW                                = name "__lt__"
leKW                                = name "__le__"
gtKW                                = name "__gt__"
geKW                                = name "__ge__"
isKW                                = name "__is__"
isnotKW                             = name "__isnot__"

compopKWs                           = [eqKW,neKW,ltKW,leKW,gtKW,geKW,isKW,isnotKW]

attrKWs                             = methKWs ++ iopKWs ++ binopKWs ++ unopKWs ++ compopKWs

nBuiltin                            = name "__builtin__"
mBuiltin                            = ModName [nBuiltin]
qBuiltin n                          = QName mBuiltin n

nStruct                             = name "struct"
nObject                             = name "object"
nInt                                = name "int"
nFloat                              = name "float"
nBool                               = name "bool"
nStr                                = name "str"
nBytes                              = name "bytes"
nRef                                = name "Ref"
nMsg                                = name "Msg"
nException                          = name "Exception"
nStopIteration                      = name "StopIteration"
nValueError                         = name "ValueError"
---
nRange                              = name "range"
nLen                                = name "len"
nPrint                              = name "print"
nDict                               = name "dict"
nList                               = name "list"
nSetT                               = name "set"
---
nSequence                           = name "Sequence"
nMapping                            = name "Mapping"
nSetP                               = name "Set"
nIndexed                            = name "Indexed"
nSliceable                          = name "Sliceable"
nHashable                           = name "Hashable"
nPlus                               = name "Plus"
nMinus                              = name "Minus"
nNumber                             = name "Number"
nReal                               = name "Real"
nRational                           = name "Rational"
nIntegral                           = name "Integral"
nLogical                            = name "Logical"
nMatrix                             = name "Matrix"
nEq                                 = name "Eq"
nOrd                                = name "Ord"
nIdentity                           = name "Identity"
nCollection                         = name "Collection"
nContainer                          = name "Container"
nIterable                           = name "Iterable"
nContextManager                     = name "ContextManager"
nShow                               = name "Show"

qnStruct                            = qBuiltin nStruct
qnObject                            = qBuiltin nObject
qnInt                               = qBuiltin nInt
qnFloat                             = qBuiltin nFloat
qnBool                              = qBuiltin nBool
qnStr                               = qBuiltin nStr
qnBytes                             = qBuiltin nBytes
qnRef                               = qBuiltin nRef
qnMsg                               = qBuiltin nMsg
qnException                         = qBuiltin nException
qnStopIteration                     = qBuiltin nStopIteration
qnValueError                        = qBuiltin nValueError
qnLen                               = qBuiltin nLen
---
qnRange                             = qBuiltin nRange
qnPrint                             = qBuiltin nPrint
qnDict                              = qBuiltin nDict
qnList                              = qBuiltin nList
qnSetT                              = qBuiltin nSetT
---
qnSequence                          = qBuiltin nSequence
qnMapping                           = qBuiltin nMapping
qnSetP                              = qBuiltin nSetP
qnIndexed                           = qBuiltin nIndexed
qnSliceable                         = qBuiltin nSliceable
qHashable                           = qBuiltin nHashable
qnPlus                              = qBuiltin nPlus
qnMinus                             = qBuiltin nMinus
qnNumber                            = qBuiltin nNumber
qnReal                              = qBuiltin nReal
qnRational                          = qBuiltin nRational
qnIntegral                          = qBuiltin nIntegral
qnLogical                           = qBuiltin nLogical
qnMatrix                            = qBuiltin nMatrix
qnEq                                = qBuiltin nEq
qnOrd                               = qBuiltin nOrd
qnIdentity                          = qBuiltin nIdentity
qnCollection                        = qBuiltin nCollection
qnContainer                         = qBuiltin nContainer
qnIterable                          = qBuiltin nIterable
qnContextManager                    = qBuiltin nContextManager
qnShow                              = qBuiltin nShow

cStruct                             = TC qnStruct []
cObject                             = TC qnObject []
cInt                                = TC qnInt []
cFloat                              = TC qnFloat []
cBool                               = TC qnBool []
cStr                                = TC qnStr []
cBytes                              = TC qnBytes []
cRef                                = TC qnRef []
cMsg a                              = TC qnMsg [a]
cList a                             = TC qnList [a]
cDict a b                           = TC qnDict [a,b]
cSet a                              = TC qnSetT [a]
cException                          = TC qnException []
cStopIteration                      = TC qnStopIteration []
cValueError                         = TC qnValueError []
---
pSequence a                         = TC qnSequence [a]
pMapping a b                        = TC qnMapping [a,b]
pSet a                              = TC qnSetP [a]
pIndexed a b                        = TC qnIndexed [a,b]
pSliceable a                        = TC qnSliceable [a]
pHashable                           = TC qHashable []
pPlus                               = TC qnPlus []
pMinus                              = TC qnMinus []
pNumber                             = TC qnNumber []
pReal                               = TC qnReal []
pRational                           = TC qnRational []
pIntegral                           = TC qnIntegral []
pLogical                            = TC qnLogical []
pMatrix                             = TC qnMatrix []
pEq                                 = TC qnEq []
pOrd                                = TC qnOrd []
pIdentity                           = TC qnIdentity []
pCollection a                       = TC qnCollection [a]
pContainer a                        = TC qnContainer [a]
pIterable a                         = TC qnIterable [a]
pContextManager                     = TC qnContextManager []
pShow                               = TC qnShow []

tStruct                             = tCon cStruct
tObject                             = tCon cObject
tInt                                = tCon cInt
tFloat                              = tCon cFloat
tBool                               = tCon cBool
tStr                                = tCon cStr
tBytes                              = tCon cBytes
tRef                                = tCon cRef
tMsg a                              = tCon (cMsg a)
tList a                             = tCon (cList a)
tDict a b                           = tCon (cDict a b)
tSet a                              = tCon (cSet a)
tException                          = tCon cException
tStopIteration                      = tCon cStopIteration
tValueError                         = tCon cValueError
---
tSequence a                         = tCon (pSequence a)
tMapping a b                        = tCon (pMapping a b)
tSetExist a                         = tCon (pSet a)
tCollection a                       = tCon (pCollection a)

witIdentityOpt                      = qBuiltin $ name "Identity$opt"
witEqOpt                            = qBuiltin $ name "Eq$opt"
witIdentityNone                     = qBuiltin $ name "Identity$None"
witEqNone                           = qBuiltin $ name "Eq$None"
witEqUnion                          = qBuiltin $ name "Eq$union"
witOrdStr                           = qBuiltin $ name "Ord$str"
witEqStr                            = witOrdStr
