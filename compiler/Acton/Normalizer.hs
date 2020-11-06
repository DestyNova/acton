{-# LANGUAGE FlexibleInstances, FlexibleContexts #-}
module Acton.Normalizer where

import Acton.Syntax
import Acton.Names
import Acton.Env
import Acton.QuickType
import Acton.Prim
import Acton.Builtin
import Utils
import Control.Monad.State.Lazy
import Debug.Trace

normalize                           :: Env0 -> Module -> IO (Module, Env0)
normalize env0 m                    = return (evalState (norm env m) 0, mapModules1 conv env0)
  where env                         = normEnv env0
        

--  Normalization:
--  X All module aliases are replaced by their original module name
--  X All parameters are positional
--  X Parameter defaults are moved inside function definitions
--  - Comprehensions are translated into loops
--  X String literals are concatenated and delimited by double quotes
--  X Tuple (and list) patterns are replaced by a var pattern followed by explicit element assignments
--  - With statemenmts are replaced by enter/exit prim calls + exception handling
--  X The assert statement is replaced by a prim call ASSERT
--  X The raise statement is replaced by one of prim calls RAISE, RAISEFROM or RERAISE
--  X Return without argument is replaced by return None
--  - The else branch of a while loop is replaced by an explicit if statement enclosing the loop


-- Normalizing monad
type NormM a                        = State Int a

newName                             :: String -> NormM Name
newName s                           = do n <- get
                                         put (n+1)
                                         return $ Internal NormPass s n

type NormEnv                        = EnvF NormX

type NormX                          = ()

normEnv env0                        = env0


-- Normalize terms ---------------------------------------------------------------------------------------

normPat                             :: NormEnv -> Pattern -> NormM (Pattern,Suite)
normPat _ p@(PVar _ _ _)            = return (p,[])
normPat env (PParen _ p)            = normPat env p
normPat env p@(PTuple _ pp kp)      = do v <- newName "tup"
                                         ss <- norm env $ normPP v 0 pp ++ normKP v [] kp
                                         return (pVar v t, ss)
  where normPP v n (PosPat p pp)    = Assign NoLoc [p] (DotI NoLoc (eVar v) n) : normPP v (n+1) pp
        normPP v n (PosPatStar p)   = [Assign NoLoc [p] (foldl (RestI NoLoc) (eVar v) [0..n-1])]
        normPP _ _ PosPatNil        = []
        normKP v ns (KwdPat n p kp) = Assign NoLoc [p] (Dot NoLoc (eVar v) n) : normKP v (n:ns) kp
        normKP v ns (KwdPatStar p)  = [Assign NoLoc [p] (foldl (Rest NoLoc) (eVar v) (reverse ns))]
        normKP _ _ KwdPatNil        = []
        t                           = typeOf env p
normPat env p@(PList _ ps pt)       = do v <- newName "lst"
                                         ss <- norm env $ normList v 0 ps pt
                                         return (pVar v t, ss)
  where normList v n (p:ps) pt      = s : normList v (n+1) ps pt
          where s                   = Assign NoLoc [p] (eCall (eDot (eQVar qnIndexed) getitemKW)
                                        [eVar v, Int NoLoc n (show n)])
        normList v n [] (Just p)    = [Assign NoLoc [p] (eCall (eDot (eQVar qnSliceable) getsliceKW)
                                        [eVar v, Int NoLoc n (show n), None NoLoc, None NoLoc])]
        normList v n [] Nothing     = [] 
        t                           = typeOf env p



class Norm a where
    norm                            :: NormEnv -> a -> NormM a
    norm'                           :: NormEnv -> a -> NormM [a]
    norm' env x                     = (:[]) <$> norm env x

instance (Norm a, EnvOf a) => Norm [a] where
    norm env []                     = return []
    norm env (a:as)                 = do as1 <- norm' env a
                                         as2 <- norm env1 as
                                         return (as1++as2)
      where env1                    = define (envOf a) env

instance Norm a => Norm (Maybe a) where
    norm env Nothing                = return Nothing
    norm env (Just a)               = Just <$> norm env a

instance Norm Module where
    norm env (Module m imps ss)     = Module m imps <$> norm env ss

instance Norm Stmt where
    norm env (Expr l e)             = Expr l <$> norm env e
    norm env (MutAssign l t e)      = MutAssign l <$> norm env t <*> norm env e
    norm env (Assert l e mbe)       = do e' <- norm env e
                                         mbe' <- norm env mbe
                                         return $ Expr l $ eCall (eQVar primASSERT) [e', maybe eNone id mbe']
    norm env (Pass l)               = return $ Pass l
    norm env (Return l Nothing)     = return $ Return l $ Just $ None l0
    norm env (Return l (Just e))    = do e' <- norm env e
                                         return $ Return l $ Just e'
    norm env (Raise l mbex)         = do mbex' <- norm env mbex
                                         case mbex' of
                                            Nothing ->
                                               return $ Expr l $ eCall (eQVar primRERAISE) []
                                            Just (Exception e Nothing) ->
                                               return $ Expr l $ eCall (eQVar primRAISE) [e]
                                            Just (Exception e (Just e')) -> 
                                               return $ Expr l $ eCall (eQVar primRAISEFROM) [e,e']
    norm env (Break l)              = return $ Break l
    norm env (Continue l)           = return $ Continue l
    norm env (If l bs els)          = If l <$> norm env bs <*> norm env els
    norm env (While l e b els)      = While l <$> norm env e <*> norm env b <*> norm env els
    norm env (Try l b hs els fin)   = Try l <$> norm env b <*> norm env hs <*> norm env els <*> norm env fin
    norm env (Data l mbt ss)        = Data l <$> norm env mbt <*> norm env ss
    norm env (VarAssign l ps e)     = VarAssign l <$> norm env ps <*> norm env e
    norm env (After l e e')         = After l <$> norm env e <*> norm env e'
    norm env (Decl l ds)            = Decl l <$> norm env1 ds
      where env1                    = define (envOf ds) env
    norm env (Signature l ns t d)   = return $ Signature l ns (conv t) d
    norm env s                      = error ("norm unexpected stmt: " ++ prstr s)    

    norm' env (Assign l tgs e)      = do e' <- norm env e
                                         ps <- mapM (normPat env) tgs
                                         let (vs,sss) = unzip ps
                                         ss' <- norm env (concat sss)
                                         return $ Assign l vs e' : ss'
      where t                       = typeOf env e
    norm' env (For l p e b els)     = do i <- newName "iter"
                                         v <- newName "val"
                                         norm env [sAssign (pVar i t) e,
                                                   sAssign (pVar v $ tOpt $ head ts) (next i),
                                                   While l (test v) (sAssign p (eVar v) : b ++ [sAssign (pVar' v) (next i)]) els]
      where t@(TCon _ (TC c ts))    = typeOf env e
            test v                  = eCall (tApp (eQVar primISNOTNONE) [head ts]) [eVar v]
            next i                  = eCall (eDot (eVar i) nextKW) []
    {-
    with EXPRESSION as PATTERN:
        SUITE
    ===>
    $mgr = EXPRESSION
    $val = $mgr.__enter__()
    $exc = False
    try:
        PATTERN = $val
        SUITE
    except Exception as ex:
        $exc = True
        if not $mgr.__exit__(ex):
            raise
    finally:
        if not $exc:
            $mgr.__exit__(None)
    -}
    norm' env s@(With l (i:is) b)   = do notYet l s                     -- TODO: remove
                                         m <- newName "mgr"
                                         v <- newName "val"
                                         x <- newName "exc"
                                         (e,mbp,ss) <- normItem env i
                                         b' <- norm env1 (ss ++ b)
                                         return undefined
      where env1                    = define (envOf i) env
    norm' env (With l [] b)         = norm env b
    norm' env s                     = do s' <- norm env s
                                         return [s']

normItem env (WithItem e Nothing)   = do e' <- norm env e
                                         return (e', Nothing, [])
normItem env (WithItem e (Just p))  = do e' <- norm env e
                                         (p',ss) <- normPat env p
                                         return (e', Just p', ss)


instance Norm Decl where
    norm env (Def l n q p k t b d x)= do p' <- joinPar <$> norm env0 p <*> norm (define (envOf p) env0) k
                                         b' <- norm env1 b
                                         return $ Def l n q (noDefaults p') KwdNIL t (defaults p' ++ b') d x
      where env1                    = define (envOf p ++ envOf k) env0
            env0                    = defineTVars q env
    norm env (Actor l n q p k b)    = do p' <- joinPar <$> norm env0 p <*> norm (define (envOf p) env0) k
                                         b' <- norm env1 b
                                         return $ Actor l n q (noDefaults p') KwdNIL (defaults p' ++ b')
      where env1                    = define (envOf p ++ envOf k) env0
            env0                    = defineTVars q env
    norm env (Class l n q as b)     = Class l n q as <$> norm env1 b
      where env1                    = defineSelf (NoQ n) q $ defineTVars q env
    norm env d                      = error ("norm unexpected: " ++ prstr d)



catStrings ['"':s]                  = '"' : s
catStrings ss                       = '"' : (escape '"' (concatMap stripQuotes ss)) ++ ['"']
  where escape c []                 = []
        escape c ('\\':x:xs)        = '\\' : x : escape c xs
        escape c (x:xs)
          | x == c                  = '\\' : x : escape c xs
          | otherwise               = x : escape c xs
        stripQuotes s               = init $ tail s

instance Norm Expr where
    norm env (Var l nm)             = return $ Var l nm
    norm env (Int l i s)            = Int l <$> return i <*> return s
    norm env (Float l f s)          = Float l <$> return f <*> return s
    norm env (Imaginary l i s)      = Imaginary l <$> return i <*> return s
    norm env (Bool l b)             = Bool l <$> return b
    norm env (None l)               = return $ None l
    norm env (NotImplemented l)     = return $ NotImplemented l
    norm env (Ellipsis l)           = return $ Ellipsis l
    norm env (Strings l ss)         = return $ Strings l [catStrings ss]
    norm env (BStrings l ss)        = return $ BStrings l [catStrings ss]
    norm env (Call l e ps ks)       = Call l <$> norm env e <*> norm env (joinArg ps ks) <*> pure KwdNil
    norm env (TApp l e ts)          = TApp l <$> norm env e <*> pure ts
    norm env (Await l e)            = Await l <$> norm env e
    norm env (Cond l e1 e2 e3)      = Cond l <$> norm env e1 <*> norm env e2 <*> norm env e3
    norm env (IsInstance l e c)     = IsInstance l <$> norm env e <*> pure c
    norm env (BinOp l e1 Or e2)     = BinOp l <$> norm env e1 <*> pure Or <*> norm env e2
    norm env (BinOp l e1 And e2)    = BinOp l <$> norm env e1 <*> pure And <*> norm env e2
    norm env (UnOp l Not e)         = UnOp l Not <$> norm env e
    norm env (Dot l e nm)           = Dot l <$> norm env e <*> pure nm
    norm env (Rest l e nm)          = Rest l <$> norm env e <*> pure nm
    norm env (DotI l e i)           = DotI l <$> norm env e <*> pure i
    norm env (RestI l e i)          = RestI l <$> norm env e <*> pure i
    norm env (Lambda l p k e fx)    = do p' <- joinPar <$> norm env p <*> norm (define (envOf p) env) k
                                         Lambda l (noDefaults p') KwdNIL <$> norm env1 e <*> return fx      -- TODO: replace defaulted params with Conds
      where env1                    = define (envOf p ++ envOf k) env
    norm env (Yield l e)            = Yield l <$> norm env e
    norm env (YieldFrom l e)        = YieldFrom l <$> norm env e
    norm env (Tuple l es ks)        = Tuple l <$> norm env es <*> norm env ks
    norm env (List l es)            = List l <$> norm env es
    norm env e0@(ListComp l e c)    = notYet l e0                                   -- TODO: eliminate here
      where env1                    = define (envOf c) env
    norm env (Paren l e)            = norm env e
    norm env e                      = error ("norm unexpected: " ++ prstr e)

instance Norm Pattern where
    norm env (PVar l n a)           = return $ PVar l n a
    norm env (PTuple l ps ks)       = PTuple l <$> norm env ps <*> norm env ks
    norm env (PList l ps p)         = PList l <$> norm env ps <*> norm env p        -- TODO: eliminate here
    norm env (PParen l p)           = norm env p

instance Norm Exception where
    norm env (Exception e mbe)      = Exception <$> norm env e <*> norm env mbe

instance Norm Branch where
    norm env (Branch e ss)          = Branch <$> norm env e <*> norm env ss

instance Norm Handler where
    norm env (Handler ex b)         = Handler ex <$> norm env1 b
      where env1                    = define (envOf ex) env

instance Norm PosPar where
    norm env (PosPar n t e p)       = PosPar n t <$> norm env e <*> norm (define [(n,NVar $ fromJust t)] env) p
    norm env (PosSTAR n t)          = return $ PosSTAR n t
    norm env PosNIL                 = return PosNIL
    
instance Norm KwdPar where
    norm env (KwdPar n t e k)       = KwdPar n t <$> norm env e <*> norm (define [(n,NVar $ fromJust t)] env) k
    norm env (KwdSTAR n t)          = return $ KwdSTAR n t
    norm env KwdNIL                 = return KwdNIL

joinPar (PosPar n t e p) k          = PosPar n t e (joinPar p k)
joinPar (PosSTAR n t) k             = PosPar n t Nothing (kwdToPosPar k)        -- TODO: sort this out...
joinPar PosNIL k                    = kwdToPosPar k

kwdToPosPar (KwdPar n t e k)        = PosPar n t e (kwdToPosPar k)
kwdToPosPar (KwdSTAR n t)           = PosPar n t Nothing PosNIL
kwdToPosPar KwdNIL                  = PosNIL

joinArg (PosArg e p) k              = PosArg e (joinArg p k)
joinArg (PosStar e) k               = PosArg e (kwdToPosArg k)                  -- TODO: sort this out...
joinArg PosNil k                    = kwdToPosArg k

kwdToPosArg (KwdArg n e k)          = PosArg e (kwdToPosArg k)
kwdToPosArg (KwdStar e)             = PosArg e PosNil
kwdToPosArg KwdNil                  = PosNil

defaults (PosPar n (Just t) (Just e) p)
                                    = s : defaults p
  where s                           = sIf1 test [set] []
        test                        = eCall (tApp (eQVar primISNOTNONE) [t]) [eVar n]
        set                         = sAssign (pVar' n) e
defaults (PosPar n _ Nothing p)     = defaults p
defaults _                          = []

noDefaults (PosPar n t _ p)         = PosPar n t Nothing (noDefaults p)
noDefaults p                        = p

instance Norm PosArg where
    norm env (PosArg e p)           = PosArg <$> norm env e <*> norm env p
    norm env (PosStar e)            = PosStar <$> norm env e
    norm env PosNil                 = return PosNil
    
instance Norm KwdArg where
    norm env (KwdArg n e k)         = KwdArg n <$> norm env e <*> norm env k
    norm env (KwdStar e)            = KwdStar <$> norm env e
    norm env KwdNil                 = return KwdNil
    
instance Norm PosPat where
    norm env (PosPat p ps)          = PosPat <$> norm env p <*> norm env ps
    norm env (PosPatStar p)         = PosPatStar <$> norm env p
    norm env PosPatNil              = return PosPatNil
    
instance Norm KwdPat where
    norm env (KwdPat n p ps)        = KwdPat n <$> norm env p <*> norm env ps
    norm env (KwdPatStar p)         = KwdPatStar <$> norm env p
    norm env KwdPatNil              = return KwdPatNil
    
instance Norm Comp where
    norm env (CompFor l p e c)      = CompFor l <$> norm env p <*> norm env e <*> norm (define (envOf p) env) c
    norm env (CompIf l e c)         = CompIf l <$> norm env e <*> norm env c
    norm env NoComp                 = return NoComp

instance Norm Elem where
    norm env (Elem e)               = Elem <$> norm env e
    norm env (Star e)               = Star <$> norm env e               -- TODO: eliminate here


-- Convert function types ---------------------------------------------------------------------------------

class Conv a where
    conv                            :: a -> a

instance (Conv a) => Conv [a] where
    conv                            = map conv

instance (Conv a) => Conv (Name, a) where
    conv (n, x)                     = (n, conv x)

instance Conv NameInfo where
    conv (NAct q p k te)            = NAct q (joinRow p k) kwdNil (conv te)
    conv (NClass q ps te)           = NClass q (conv ps) (conv te)
    conv (NSig sc dec)              = NSig (conv sc) dec
    conv (NDef sc dec)              = NDef (conv sc) dec
    conv (NVar t)                   = NVar (conv t)
    conv (NSVar t)                  = NSVar (conv t)
    conv ni                         = ni

instance Conv WTCon where
    conv (w,c)                      = (w, conv c)

instance Conv TSchema where
    conv (TSchema l q t)            = TSchema l q (conv t)

instance Conv Type where
    conv (TFun l fx p k t)          = TFun l fx (joinRow p k) kwdNil (conv t)
    conv (TCon l c)                 = TCon l (conv c)
    conv (TTuple l p k)             = TTuple l (conv p) (conv k)
    conv (TOpt l t)                 = TOpt l (conv t)
    conv (TRow l k n t r)           = TRow l k n (conv t) (conv r)
    conv t                          = t

instance Conv TCon where
    conv (TC c ts)                  = TC c (conv ts)

joinRow (TRow l k n t p) r          = TRow l k n (conv t) (joinRow p r)
joinRow (TNil l k) r                = toPosRow r
joinRow t r                         = TRow (loc t) PRow (name "_") (conv t) (toPosRow r)

toPosRow (TRow l k n t r)           = TRow l k (name "_") t (toPosRow r)
toPosRow (TNil l k)                 = TNil l PRow
toPosRow t                          = TRow (loc t) PRow (name "_") (conv t) posNil
