{-# LANGUAGE FlexibleInstances, DeriveGeneric #-}
module Acton.Env where

import qualified Control.Exception
import Debug.Trace
import qualified Data.Binary
import GHC.Generics (Generic)
import qualified Data.Map.Strict as Map
import Data.Map.Strict (Map)
import Control.Monad.State.Strict
import Data.Typeable
import Data.Traversable
import System.FilePath.Posix (joinPath,takeDirectory)
import System.Directory (doesFileExist)
import System.Environment (getExecutablePath)
import Control.Monad

import Acton.Syntax
import Acton.Builtin
import Acton.Printer
import Acton.Names
import Utils
import Pretty
import InterfaceFiles
import Prelude hiding ((<>))




mkEnv                       :: (FilePath,FilePath) -> Env -> Module -> IO Env
mkEnv paths env modul       = getImps paths (setDefaultMod m env) imps
  where Module m imps _     = modul


type Schemas                = [(Name, TSchema)]

type TEnv                   = [(Name, NameInfo)]

data Env                    = Env { names :: TEnv, modules :: [(ModName,TEnv)], defaultmod :: ModName, indecl :: Bool } deriving Show

data NameInfo               = NVar      Type
                            | NSVar     Type
                            | NDef      TSchema Decoration
                            | NSig      TSchema Decoration
                            | NClass    [TBind] [TCon] TEnv
                            | NProto    [TBind] [TCon] TEnv
                            | NExt      QName [TBind] [TCon] TEnv
                            | NTVar     Kind [TCon] [TCon]
                            | NAlias    QName
                            | NMAlias   ModName
                            | NModule   TEnv
                            | NReserved
                            | NBlocked
                            deriving (Eq,Show,Read,Generic)

instance Data.Binary.Binary NameInfo

instance Pretty TEnv where
    pretty tenv                 = vcat (map pretty tenv)

instance Pretty Env where
    pretty env                  = vcat (map pretty (names env))

instance Pretty (Name,NameInfo) where
    pretty (n, NVar t)          = pretty n <+> colon <+> pretty t
    pretty (n, NSVar t)         = text "var" <+> pretty n <+> colon <+> pretty t
    pretty (n, NDef t d)        = prettyDec d $ pretty n <+> colon <+> pretty t
    pretty (n, NSig t d)        = prettyDec d $ pretty n <+> text "::" <+> pretty t
    pretty (n, NClass q us [])  = text "class" <+> pretty n <+> nonEmpty brackets commaList q <+>
                                  nonEmpty parens commaList us
    pretty (n, NClass q us te)  = text "class" <+> pretty n <+> nonEmpty brackets commaList q <+>
                                  nonEmpty parens commaList us <> colon $+$ (nest 4 $ pretty te)
    pretty (n, NProto q us [])  = text "protocol" <+> pretty n <+> nonEmpty brackets commaList q <+>
                                  nonEmpty parens commaList us
    pretty (n, NProto q us te)  = text "protocol" <+> pretty n <+> nonEmpty brackets commaList q <+>
                                  nonEmpty parens commaList us <> colon $+$ (nest 4 $ pretty te)
    pretty (w, NExt n [] ps te) = pretty w  <+> colon <+> pretty n <+> parens (commaList ps) <>
                                  colon $+$ (nest 4 $ pretty te)
    pretty (w, NExt n q ps te)  = pretty w  <+> colon <+> pretty q <+> text "=>" <+> pretty n <> 
                                  brackets (commaList $ tybound q) <+> parens (commaList ps) <>
                                  colon $+$ (nest 4 $ pretty te)
    pretty (n, NTVar k as ps)   = pretty n <> parens (commaList (as++ps))
    pretty (n, NAlias qn)       = text "alias" <+> pretty n <+> equals <+> pretty qn
    pretty (n, NMAlias m)       = text "module" <+> pretty n <+> equals <+> pretty m
    pretty (n, NModule te)      = text "module" <+> pretty n <> colon $+$ nest 4 (pretty te)
    pretty (n, NReserved)       = pretty n <+> text "(reserved)"
    pretty (n, NBlocked)        = pretty n <+> text "(blocked)"

instance Subst Env where
    msubst env                  = do ne <- msubst (names env)
                                     return env{ names = ne }
    tyfree env                  = tyfree (names env)

instance Subst NameInfo where
    msubst (NVar t)             = NVar <$> msubst t
    msubst (NSVar t)            = NSVar <$> msubst t
    msubst (NDef t d)           = NDef <$> msubst t <*> return d
    msubst (NSig t d)           = NSig <$> msubst t <*> return d
    msubst (NClass q us te)     = NClass <$> msubst q <*> msubst us <*> msubst te
    msubst (NProto q us te)     = NProto <$> msubst q <*> msubst us <*> msubst te
    msubst (NExt n q ps te)     = NExt n <$> msubst q <*> msubst ps <*> msubst te
    msubst (NTVar k as ps)      = NTVar k <$> msubst as <*> msubst ps
    msubst (NAlias qn)          = NAlias <$> return qn
    msubst (NMAlias m)          = NMAlias <$> return m
    msubst (NModule te)         = NModule <$> return te     -- actually msubst te, but te has no free variables (top-level)
    msubst NReserved            = return NReserved
    msubst NBlocked             = return NBlocked

    tyfree (NVar t)             = tyfree t
    tyfree (NSVar t)            = tyfree t
    tyfree (NDef t d)           = tyfree t
    tyfree (NSig t d)           = tyfree t
    tyfree (NClass q us te)     = (tyfree q ++ tyfree us ++ tyfree te) \\ tybound q
    tyfree (NProto q us te)     = (tyfree q ++ tyfree us ++ tyfree te) \\ tybound q
    tyfree (NExt n q ps te)     = (tyfree q ++ tyfree ps ++ tyfree te) \\ tybound q
    tyfree (NTVar k as ps)      = tyfree as ++ tyfree ps
    tyfree (NAlias qn)          = []
    tyfree (NMAlias qn)         = []
    tyfree (NModule te)         = []        -- actually tyfree te, but a module has no free variables on the top level
    tyfree NReserved            = []
    tyfree NBlocked             = []

msubstTV tvs                    = fmap tyfree $ mapM msubst $ map tVar tvs

instance Subst SrcInfoTag where
    msubst (GEN l t)                = GEN l <$> msubst t
    msubst (INS l t)                = INS l <$> msubst t

    tyfree (GEN _ t)                = tyfree t
    tyfree (INS _ t)                = tyfree t


-------------------------------------------------------------------------------------------------------------------

class Unalias a where
    unalias                         :: Env -> a -> a
    unalias env                     = id

instance (Unalias a) => Unalias [a] where
    unalias env                     = map (unalias env)

instance (Unalias a) => Unalias (Maybe a) where
    unalias env                     = fmap (unalias env)

instance Unalias ModName where
    unalias env (ModName ns0)       = norm (names env) [] ns0
      where
        norm te pre []              = ModName (reverse pre)
        norm te pre (n:ns)          = case lookup n te of
                                        Just (NModule te') -> norm te' (n:pre) ns
                                        Just (NMAlias m) -> m
                                        _ -> noModule (ModName ns0)

instance Unalias QName where
    unalias env (QName m n)         = case lookup m' (modules env) of
                                        Just te -> case lookup n te of
                                                      Just (NAlias qn) -> qn
                                                      Just _ -> QName m' n
                                                      _ -> noItem m n
      where m'                      = unalias env m
    unalias env (NoQual n)          = case lookup n (names env) of
                                        Just (NAlias qn) -> qn
                                        Just _ -> QName (defaultmod env) n
                                        _ -> trace ("#unalias") $ nameNotFound n
                                    
instance Unalias TSchema where
    unalias env (TSchema l q t)     = TSchema l (unalias env q) (unalias env t)

instance Unalias TCon where
    unalias env (TC qn ts)          = TC (unalias env qn) (unalias env ts)

instance Unalias TBind where
    unalias env (TBind tv cs)       = TBind tv (unalias env cs)

instance Unalias Type where
    unalias env (TCon l c)          = TCon l (unalias env c)
    unalias env (TExist l p)        = TExist l (unalias env p)
    unalias env (TFun l e p r t)    = TFun l (unalias env e) (unalias env p) (unalias env r) (unalias env t)
    unalias env (TTuple l p k)      = TTuple l (unalias env p) (unalias env k)
    unalias env (TOpt l t)          = TOpt l (unalias env t)
    unalias env (TRow l k n t r)    = TRow l k n (unalias env t) (unalias env r)
    unalias env t                   = t

instance Unalias NameInfo where
    unalias env (NVar t)            = NVar (unalias env t)
    unalias env (NSVar t)           = NSVar (unalias env t)
    unalias env (NDef t d)          = NDef (unalias env t) d
    unalias env (NSig t d)          = NSig (unalias env t) d
    unalias env (NClass q us te)    = NClass (unalias env q) (unalias env us) (unalias env te)
    unalias env (NProto q us te)    = NProto (unalias env q) (unalias env us) (unalias env te)
    unalias env (NExt n q ps te)    = NExt (unalias env n) (unalias env q) (unalias env ps) (unalias env te)
    unalias env (NTVar k as ps)     = NTVar k (unalias env as) (unalias env ps)
    unalias env (NAlias qn)         = NAlias (unalias env qn)
    unalias env (NModule te)        = NModule (unalias env te)
    unalias env NReserved           = NReserved
    unalias env NBlocked            = NBlocked

instance Unalias (Name,NameInfo) where
    unalias env (n,i)               = (n, unalias env i)
    
-- TEnv filters --------------------------------------------------------------------------------------------------------

nSigs                       :: TEnv -> TEnv
nSigs te                    = [ (n,i) | (n, i@(NSig sc dec)) <- te ]

nTerms                      :: TEnv -> TEnv
nTerms te                   = [ (n,i) | (n,i) <- te, isTerm i ]
  where isTerm NDef{}       = True
        isTerm NVar{}       = True
        isTerm _            = False

sigTerms                    :: TEnv -> (TEnv, TEnv)
sigTerms te                 = (nSigs te, nTerms te)

propSigs                    :: TEnv -> TEnv
propSigs te                 = [ (n,i) | (n, i@(NSig sc dec)) <- te, isProp dec sc ]
  where isProp Property _   = True
        isProp NoDec sc     = case sctype sc of TFun{} -> False; _ -> True
        isProp _ _          = False

nSchemas                    :: TEnv -> Schemas
nSchemas []                 = []
nSchemas ((n,NVar t):te)    = (n, monotype t) : nSchemas te
nSchemas ((n,NDef sc d):te) = (n, sc) : nSchemas te
nSchemas (_:te)             = nSchemas te

parentTEnv                  :: Env -> [TCon] -> TEnv
parentTEnv env us           = concatMap tEnv us
  where tEnv u              = case findQName (tcname u) env of
                                NClass q _ te -> subst (tybound q `zip` tcargs u) te
                                NProto q _ te -> subst (tybound q `zip` tcargs u) te
--                                NExt _ q us' te -> 
                                _             -> []

splitTEnv                   :: [Name] -> TEnv -> (TEnv, TEnv)
splitTEnv vs te             = partition ((`elem` vs) . fst) te


-- Env construction and modification -------------------------------------------------------------------------------------------

initEnv                    :: Bool -> IO Env
initEnv nobuiltin           = if nobuiltin
                                then return $ Env{names = [], modules = [], defaultmod = mBuiltin, indecl = False}
                                else do path <- getExecutablePath
                                        envBuiltin <- InterfaceFiles.readFile (joinPath [takeDirectory path,"__builtin__.ty"])
                                        let autoImp = importAll mBuiltin envBuiltin
                                            env0    = Env{names = [(nBuiltin,NModule envBuiltin)], modules = [(mBuiltin,envBuiltin)],
                                                          defaultmod = mBuiltin, indecl = False}
                                            env     = define autoImp env0
                                        return env
                                        
setDefaultMod               :: ModName -> Env -> Env
setDefaultMod m env         = env{ defaultmod = m }

setInDecl                   :: Env -> Env
setInDecl env               = env{ indecl = True }

addMod                      :: ModName -> TEnv -> Env -> Env
addMod m te env             = env{ modules = (m,te) : modules env }

reserve                     :: [Name] -> Env -> Env
reserve xs env              = env{ names = [ (x, NReserved) | x <- nub xs ] ++ names env }

block                       :: [Name] -> Env -> Env
block xs env                = env{ names = [ (x, NBlocked) | x <- nub xs ] ++ names env }

define                      :: TEnv -> Env -> Env
define te env               = env{ names = reverse te ++ prune (dom te) (names env) }

defineTVars                 :: [TBind] -> Env -> Env
defineTVars [] env          = env
defineTVars (TBind (TV k n) us : q) env
                            = defineTVars q env{ names = (n, NTVar k as ps) : names env }
  where (as,ps)             = mro2 env us

defineSelf                  :: QName -> [TBind] -> Env -> Env
defineSelf qn q env         = defineTVars [TBind tvSelf [tc]] env
  where tc                  = TC qn [ tVar tv | TBind tv _ <- q ]


defineMod                   :: ModName -> TEnv -> Env -> Env
defineMod m te env          = define [(n, defmod ns $ te1)] env
  where ModName (n:ns)      = m
        te1                 = case lookup n (names env) of Just (NModule te1) -> te1; _ -> []
        defmod [] te1       = NModule $ te
        defmod (n:ns) te1   = NModule $ (n, defmod ns te2) : prune [n] te1
          where te2         = case lookup n te1 of Just (NModule te2) -> te2; _ -> []


-- General Env queries -----------------------------------------------------------------------------------------------------------

inBuiltin                   :: Env -> Bool
inBuiltin env               = null $ modules env

inDecl                      :: Env -> Bool
inDecl env                  = indecl env

stateScope                  :: Env -> [Name]
stateScope env              = [ z | (z, NSVar _) <- names env ]

tvarScope                   :: Env -> [TVar]
tvarScope env               = [ TV k n | (n, NTVar k _ _) <- names env ]


-- Name queries -------------------------------------------------------------------------------------------------------------------

findQName                   :: QName -> Env -> NameInfo 
findQName (QName m n) env   = case maybeFindMod (unalias env m) env of
                                Just te -> case lookup n te of
                                    Just (NAlias qn) -> findQName qn env
                                    Just i -> i
                                    _ -> noItem m n
                                _ -> noModule m
findQName (NoQual n) env    = case lookup n (names env) of
                                Just (NAlias qn) -> findQName qn env
                                Just info -> info
                                Nothing -> trace ("#findQName") $ nameNotFound n

findName n env              = findQName (NoQual n) env

maybeFindMod                :: ModName -> Env -> Maybe TEnv
maybeFindMod (ModName ns) env = f ns (names env)
  where f [] te             = Just te
        f (n:ns) te         = case lookup n te of
                                Just (NModule te') -> f ns te'
                                Just (NMAlias m) -> maybeFindMod m env
                                _ -> Nothing

isMod                       :: Env -> [Name] -> Bool
isMod env ns                = maybe False (const True) (maybeFindMod (ModName ns) env)


tconKind                    :: QName -> Env -> Kind
tconKind n env              = case findQName n env of
                                NClass q _ _ -> kind KType q
                                NProto q _ _ -> kind KProto q
                                _            -> notClassOrProto n
  where kind k []           = k
        kind k q            = KFun [ tvkind v | TBind v _ <- q ] k
                                
isProto                     :: QName -> Env -> Bool
isProto n env               = case findQName n env of
                                NProto q us te -> True
                                _ -> False

findExtension               :: QName -> QName -> Env -> Maybe (Name,[TBind],TCon)
findExtension n tc env      = case [ (w,q,p) | (w,q,ps) <- extensionsOf n env, p <- ps, tc == tcname p ] of
                                [(w,q,p)] -> Just (w,q,p)
                                _ -> Nothing


extensionsOf                :: QName -> Env -> [(Name,[TBind],[TCon])]
extensionsOf n env          = [ (w,q,ps) | (w, NExt n' q ps _) <- names env, n == n' ]



constraintsOf               :: [TBind] -> Env -> Constraints
constraintsOf q env         = [ constr u (tVar v) | TBind v us <- q, u <- us ]
  where constr u t          = if isProto (tcname u) env then Impl (name "_") t u else Cast t (tCon u) 


-- TCon queries ------------------------------------------------------------------------------------------------------------------

findAttr                    :: Env -> TCon -> Name -> (TSchema,Decoration)
findAttr env tc n           = findIn (te ++ concat tes)
  where (us,te)             = findCon env tc
        tes                 = [ te' | u <- us, let (_,te') = findCon env u ]
        findIn te1          = case lookup n te1 of
                                Just (NSig sc d)      -> (sc,NoDec)
                                Nothing               -> err1 n "Attribute not found:"

findCon                     :: Env -> TCon -> ([TCon],TEnv)
findCon env (TC n ts)
  | map tVar tvs == ts      = (us, te)
  | otherwise               = (subst s us, subst s te)
  where (q,us,te)           = case findQName n env of
                                NClass q us te -> (q,us,te)
                                NProto q us te -> (q,us,te)
                                NExt n q us te -> (q,us,te)
                                i -> err1 n ("findCon: Class or protocol name expected, got " ++ show i ++ " --- ")
        tvs                 = tybound q
        s                   = tvs `zip` ts


-- Well-formed tycon applications -------------------------------------------------------------------------------------------------

wellformed env x            = wf env x

class WellFormed a where
    wf                      :: Env -> a -> Constraints

instance (WellFormed a) => WellFormed (Maybe a) where
    wf env                  = maybe [] (wf env)

instance (WellFormed a) => WellFormed [a] where
    wf env                  = concatMap (wf env)

instance (WellFormed a, WellFormed b) => WellFormed (a,b) where
    wf env (a,b)            = wf env a ++ wf env b

instance WellFormed TCon where
    wf env (TC n ts)        = wf env ts ++ subst s (constraintsOf q env)
      where q               = case findQName n env of
                                NClass q us te -> q
                                NProto q us te -> q
                                i -> err1 n ("wf: Class or protocol name expected, got " ++ show i ++ " --- ")
            s               = tybound q `zip` ts

instance WellFormed Type where
    wf env (TCon _ tc)      = wf env tc
    wf env (TExist _ tc)    = wf env tc
    wf env (TFun _ x p k t) = wf env x ++ wf env p ++ wf env p ++ wf env k ++ wf env t
    wf env (TTuple _ p k)   = wf env p ++ wf env k
    wf env (TOpt _ t)       = wf env t
    wf env (TRow _ _ _ t r) = wf env t ++ wf env r
    wf env _                = []


instance WellFormed TBind where
    wf env (TBind v us)     = wf env us

entail env (Impl w t p)     = case t of
                                TCon _ (TC n ts) -> 
                                  case findExtension n (tcname p) env of
                                    Just (_,q,u) -> subst s u == p && all (entail env) (subst s $ constraintsOf q env)
                                      where s = tybound q `zip` ts
                                    Nothing -> err1 (Impl w t p) "No entailment"
                                TVar _ tv -> p `elem` ps
                                  where ps = findProtoBound tv env
                                _ -> err1 (Impl w t p) "No entailment"
entail env (Cast t u)       = case (t,u) of
                                (TCon _ tc, TCon _ tc') -> tc' `elem` us
                                  where (us,_) = findCon env tc
                                (TVar _ tv, TCon _ tc') -> tc' `elem` us
                                  where us = findClassBound tv env 
                                _ -> err1 (Cast t u) "No entailment"
entail env c                = err1 c "No entailment"


-- Method resolution order ------------------------------------------------------------------------------------------------------

mro2 env []                             = ([], [])
mro2 env (u:us)
  | isProto (tcname u) env              = ([], mro env (u:us))
  | otherwise                           = (mro env [u], mro env us)

mro env us                              = merge [] $ linearizations us ++ [us]
  where merge out lists
          | null heads                  = reverse out
          | h:_ <- good                 = merge (h:out) [ if equal hd h then tl else hd:tl | (hd,tl) <- zip heads tails ]
          | otherwise                   = err2 heads "Inconsistent resolution order for"
          where (heads,tails)           = unzip [ (hd,tl) | hd:tl <- lists ]
                good                    = [ h | h <- heads, all (absent (tcname h)) tails]

        equal u1 u2
          | u1 == u2                    = True
          | tcname u1 == tcname u2      = err2 [u1,u2] "Inconsistent protocol instantiations"
          | otherwise                   = False

        absent n []                     = True
        absent n (u:us)
          | n == tcname u               = False
          | otherwise                   = absent n us

        linearizations []               = []
        linearizations (u : us)         = (u:us') : linearizations us
          where (us',_)                 = findCon env u


-- TVar queries ------------------------------------------------------------------------------------------------------------------

findClassBound              :: TVar -> Env -> [TCon]
findClassBound tv env       = case findName (tvname tv) env of
                                NTVar _ as us -> as
                                _ -> []

findProtoBound              :: TVar -> Env -> [TCon]
findProtoBound tv env       = case findName (tvname tv) env of
                                NTVar _ as ps -> ps
                                _ -> []

-- Instantiation -------------------------------------------------------------------------------------------------------------------

instantiate                 :: Env -> TSchema -> TypeM (Constraints, Type)
instantiate env (TSchema _ [] t)
                            = return ([], t)
instantiate env (TSchema _ q t)
                            = do tvs <- newTVars [ tvkind v | TBind v _ <- q ]
                                 let s = tybound q `zip` tvs
                                 cs <- sequence [ constr (tVar v) u | TBind v us <- subst s q, u <- us ]
                                 return (cs, subst s t)
  where constr t u@(TC n _)
          | isProto n env   = do w <- newWitness; return $ Impl w t u
          | otherwise       = return $ Cast t (tCon u)



-- Import handling (local definitions only) ----------------------------------------------

getImps                         :: (FilePath,FilePath) -> Env -> [Import] -> IO Env
getImps ps env []               = return env
getImps ps env (i:is)           = do env' <- impModule ps env i
                                     getImps ps env' is


impModule                       :: (FilePath,FilePath) -> Env -> Import -> IO Env
impModule ps env (Import _ ms)  = imp env ms
  where imp env []              = return env
        imp env (ModuleItem m as : is)
                                = do (env1,te) <- doImp ps env m
                                     let env2 = maybe (defineMod m te env1) (\n->define [(n, NMAlias m)] env1) as
                                     imp env2 is
impModule ps env (FromImport _ (ModRef (0,Just m)) items)
                                = do (env1,te) <- doImp ps env m
                                     return $ define (importSome items m te) env1
impModule ps env (FromImportAll _ (ModRef (0,Just m)))
                                = do (env1,te) <- doImp ps env m
                                     return $ define (importAll m te) env1
impModule _ _ i                 = illegalImport (loc i)


doImp (p,sysp) env m            = case lookup m (modules env) of
                                    Just te -> return (env, te)
                                    Nothing -> do
                                        found <- doesFileExist fpath
                                        if found
                                         then do te <- InterfaceFiles.readFile fpath
                                                 return (defineMod m te (addMod m te env), te)
                                         else do found <- doesFileExist fpath2
                                                 unless found (fileNotFound m)
                                                 te <- InterfaceFiles.readFile fpath2
                                                 return (defineMod m te (addMod m te env), te)
  where fpath                   = joinPath (p : mpath m) ++ ".ty"
        fpath2                  = joinPath (sysp : mpath m) ++ ".ty"
        mpath (ModName ns)      = map nstr ns


importSome                  :: [ImportItem] -> ModName -> TEnv -> TEnv
importSome items m te       = map pick items
  where 
    te1                     = importAll m te
    pick (ImportItem n mbn) = case lookup n te1 of
                                    Just i  -> (maybe n id mbn, i) 
                                    Nothing -> noItem m n

importAll                   :: ModName -> TEnv -> TEnv
importAll m te              = mapMaybe imp te
  where 
    imp (n, NProto _ _ _)   = Just (n, NAlias (QName m n))
    imp (n, NClass _ _ _)   = Just (n, NAlias (QName m n))
    imp (n, NExt _ _ _ _)   = Nothing
    imp (n, NAlias _)       = Just (n, NAlias (QName m n))
    imp (n, NVar t)         = Just (n, NAlias (QName m n))
    imp (n, NDef t d)       = Just (n, NAlias (QName m n))
    imp _                   = Nothing                               -- cannot happen


-- Type inference monad ------------------------------------------------------------------


data Constraint                         = Cast      Type Type
                                        | Sub       Name Type Type
                                        | Impl      Name Type TCon
                                        | Sel       Type Name Type
                                        | Mut       Type Name Type

instance HasLoc Constraint where
    loc (Cast _ t)                      = loc t
    loc (Sub  _ _ t)                    = loc t
    loc (Impl _ _ p)                    = loc p
    loc (Sel _ n _)                     = loc n
    loc (Mut _ n _)                     = loc n

instance Pretty Constraint where
    pretty (Cast t1 t2)                 = pretty t1 <+> text "<" <+> pretty t2
    pretty (Sub w t1 t2)                = pretty w <+> colon <+> pretty t1 <+> text "<:" <+> pretty t2
    pretty (Impl w t u)                 = pretty w <+> colon <+> pretty t <+> parens (pretty u)
    pretty (Sel t1 n t2)                = pretty t1 <+> text "." <> pretty n <+> text "~" <+> pretty t2
    pretty (Mut t1 n t2)                = pretty t1 <+> text "." <> pretty n <+> text ":~" <+> pretty t2

instance Show Constraint where
    show                                = render . pretty

type Constraints                        = [Constraint]

type TVarMap                            = Map TVar Type

data TypeState                          = TypeState {
                                                nextint         :: Int,
                                                effectstack     :: [(TFX,Type)],
                                                deferred        :: Constraints,
                                                currsubst       :: TVarMap,
                                                dumped          :: SrcInfo
                                          }

initTypeState s                         = TypeState { nextint = 1, effectstack = [], deferred = [], currsubst = s, dumped = [] }

type TypeM a                            = State TypeState a

runTypeM                                :: TypeM a -> a
runTypeM m                              = evalState m (initTypeState Map.empty)
{-
type TypeM a                            = ExceptT TypeError (State TypeState) a

runTypeM                                :: TypeM a -> a
runTypeM m                              = case evalState (runExceptT m) (initTypeState Map.empty) of
                                            Right x -> x
                                            Left err -> internal ("Unhandled TypeM error: " ++ show err)
-}
newUnique                               :: TypeM Int
newUnique                               = state $ \st -> (nextint st, st{ nextint = nextint st + 1 })

pushFX                                  :: TFX -> Type -> TypeM ()
pushFX fx ret                           = state $ \st -> ((), st{ effectstack = (fx,ret) : effectstack st })

currFX                                  :: TypeM TFX
currFX                                  = state $ \st -> (fst $ head $ effectstack st, st)

currRet                                 :: TypeM Type
currRet                                 = state $ \st -> (snd $ head $ effectstack st, st)

popFX                                   :: TypeM ()
popFX                                   = state $ \st -> ((), st{ effectstack = tail (effectstack st) })

defer                                   :: Constraints -> TypeM ()
defer cs                                = state $ \st -> ((), st{ deferred = cs ++ deferred st })

collectDeferred                         :: TypeM Constraints
collectDeferred                         = state $ \st -> (deferred st, st)

substitute                              :: TVar -> Type -> TypeM ()
substitute tv@(TV _ Internal{}) t       = state $ \st -> ((), st{ currsubst = Map.insert tv t (currsubst st)})

getSubstitution                         :: TypeM (Map TVar Type)
getSubstitution                         = state $ \st -> (currsubst st, st)

dump                                    :: SrcInfo -> TypeM ()
dump inf                                = state $ \st -> ((), st{ dumped = inf ++ dumped st })

getDump                                 :: TypeM SrcInfo
getDump                                 = state $ \st -> (dumped st, st)


newName s                               = Internal s <$> newUnique <*> return TypesPass

newWitness                              = newName "w"

newTVarOfKind k                         = TVar NoLoc <$> TV k <$> (Internal (str k) <$> newUnique <*> return GenPass)
  where str KType                       = "V"
        str KFX                         = "X"
        str PRow                        = "P"
        str KRow                        = "K"
        str _                           = "C"

newTVars ks                             = mapM newTVarOfKind ks

newTVar                                 = newTVarOfKind KType

subst                                   :: Subst a => Substitution -> a -> a
subst s x                               = evalState (msubst x) (initTypeState $ Map.fromList s)

erase x                                 = subst s x
  where s                               = [ (tv, tWild) | tv <- nub (tyfree x) ]

monotypeOf (TSchema _ [] t)             = t
monotypeOf sc                           = err1 sc "Monomorphic type expected"


class Subst t where
    msubst                          :: t -> TypeM t
    tyfree                          :: t -> [TVar]
    tybound                         :: t -> [TVar]
    tybound _                       = []

instance Subst a => Subst (Name,a) where
    msubst (n, t)                   = (,) <$> return n <*> msubst t
    tyfree (n, t)                   = tyfree t
    tybound (n, t)                  = tybound t

instance Subst a => Subst [a] where
    msubst                          = mapM msubst
    tyfree                          = concat . map tyfree
    tybound                         = concat . map tybound

instance Subst a => Subst (Maybe a) where
    msubst                          = maybe (return Nothing) (\x -> Just <$> msubst x)
    tyfree                          = maybe [] tyfree
    tybound                         = maybe [] tybound

instance Subst Constraint where
    msubst (Cast t1 t2)             = Cast <$> msubst t1 <*> msubst t2
    msubst (Sub w t1 t2)            = Sub w <$> msubst t1 <*> msubst t1
    msubst (Impl w t p)             = Impl w <$> msubst t <*> msubst p
    msubst (Sel t1 n t2)            = Sel <$> msubst t1 <*> return n <*> msubst t2
    msubst (Mut t1 n t2)            = Mut <$> msubst t1 <*> return n <*> msubst t2

    tyfree (Cast t1 t2)             = tyfree t1 ++ tyfree t2
    tyfree (Sub w t1 t2)            = tyfree t1 ++ tyfree t2
    tyfree (Impl w t p)             = tyfree t ++ tyfree p
    tyfree (Sel t1 n t2)            = tyfree t1 ++ tyfree t2
    tyfree (Mut t1 n t2)            = tyfree t1 ++ tyfree t2

instance Subst TSchema where
    msubst sc@(TSchema l q t)       = (msubst' . Map.toList . Map.filterWithKey relevant) <$> getSubstitution
      where relevant k v            = k `elem` vs0
            vs0                     = tyfree sc
            msubst' s               = TSchema l (subst s q') (subst s t')
              where vs              = tybound q
                    newvars         = tyfree (rng s)
                    clashvars       = vs `intersect` newvars
                    avoidvars       = vs0 ++ vs ++ newvars
                    freshvars       = tvarSupply \\ avoidvars
                    renaming_s      = clashvars `zip` map (TVar NoLoc) freshvars
                    q'              = [ TBind (subst renaming_s v) (subst renaming_s cs) | TBind v cs <- q ]
                    t'              = subst renaming_s t

    tyfree (TSchema _ q t)          = (tyfree q ++ tyfree t) \\ tybound q
    tybound (TSchema _ q t)         = tybound q

msubstRenaming                      :: Subst a => a -> TypeM (Substitution,Substitution)
msubstRenaming c                    = do s <- Map.toList . Map.filterWithKey relevant <$> getSubstitution
                                         return $ (dom s `zip` subst (renaming_s  (tyfree (rng s))) (rng s),renaming_s (tyfree (rng s)))
      where relevant k _            = k `elem` vs0
            vs0                     = tyfree c
            vs                      = tybound c
            renaming_s newvars      = clashvars `zip` map tVar freshvars
              where clashvars       = vs `intersect` newvars
                    avoidvars       = vs0 ++ vs ++ newvars
                    freshvars       = tvarSupply \\ avoidvars

testSchemaSubst = do
    putStrLn ("t:  " ++ render (pretty t))
    putStrLn ("s1: " ++ render (pretty s1))
    putStrLn ("s2: " ++ render (pretty s2))
    putStrLn ("s3: " ++ render (pretty s3))
    putStrLn ("subst s1 t: " ++ render (pretty (subst s1 t)))
    putStrLn ("subst s2 t: " ++ render (pretty (subst s2 t)))
    putStrLn ("subst s3 t: " ++ render (pretty (subst s3 t)))
  where t   = tSchema [TBind (TV KType (name "A")) [TC (noQual "Eq") []]]
                            (tCon (TC (noQual "apa") [tVar (TV KType (name "A")), 
                                                      tVar (TV KType (name "B"))]))
        s1  = [(TV KType (name "B"), tSelf)]
        s2  = [(TV KType (name "A"), tSelf)]
        s3  = [(TV KType (name "B"), tVar (TV KType (name "A")))]

instance Subst TVar where
    msubst v                        = do t <- msubst (TVar NoLoc v)
                                         case t of
                                            TVar _ v' -> return v'
                                            _         -> return v
    tyfree v                        = [v]
        
instance Subst TCon where
    msubst (TC n ts)                = TC n <$> msubst ts
    tyfree (TC n ts)                = tyfree ts

instance Subst TBind where
    msubst (TBind v cs)             = TBind <$> msubst v <*> msubst cs
    tyfree (TBind v cs)             = tyfree cs
    tybound (TBind v cs)            = [v]

instance Subst Type where
    msubst (TVar l v)               = do s <- getSubstitution
                                         case Map.lookup v s of
                                            Just t ->  msubst t
                                            Nothing -> return (TVar l v)
    msubst (TCon l c)               = TCon l <$> msubst c
    msubst (TExist l p)             = TExist l <$> msubst p
    msubst (TFun l fx p k t)        = TFun l <$> msubst fx <*> msubst p <*> msubst k<*> msubst t
    msubst (TTuple l p k)           = TTuple l <$> msubst p <*> msubst k
    msubst (TUnion l as)            = return $ TUnion l as
    msubst (TOpt l t)               = TOpt l <$> msubst t
    msubst (TNone l)                = return $ TNone l
    msubst (TWild l)                = return $ TWild l
    msubst (TNil l s)               = return $ TNil l s
    msubst (TRow l k n t r)         = TRow l k n <$> msubst t <*> msubst r
    msubst (TFX l fx)               = TFX l <$> msubst fx

    tyfree (TVar _ v)               = [v]
    tyfree (TCon _ c)               = tyfree c
    tyfree (TExist _ p)             = tyfree p
    tyfree (TFun _ fx p k t)        = tyfree fx ++ tyfree p ++ tyfree k ++ tyfree t
    tyfree (TTuple _ p k)           = tyfree p ++ tyfree k
    tyfree (TUnion _ as)            = []
    tyfree (TOpt _ t)               = tyfree t
    tyfree (TNone _)                = []
    tyfree (TWild _)                = []
    tyfree (TNil _ _)               = []
    tyfree (TRow _ _ _ t r)         = tyfree t ++ tyfree r
    tyfree (TFX l fx)               = tyfree fx

instance Subst FX where
    msubst (FXMut t)                = FXMut <$> msubst t
    msubst (FXAct t)                = FXAct <$> msubst t
    msubst fx                       = return fx
    
    tyfree (FXMut t)                = tyfree t
    tyfree (FXAct t)                = tyfree t
    tyfree _                        = []  
    
instance Subst PosPar where
    msubst (PosPar n t e p)         = PosPar n <$> msubst t <*> msubst e <*> msubst p
    msubst (PosSTAR n t)            = PosSTAR n <$> msubst t
    msubst PosNIL                   = return PosNIL
    
    tyfree (PosPar n t e p)         = tyfree t ++ tyfree p
    tyfree (PosSTAR n t)            = tyfree t
    tyfree PosNIL                   = []

instance Subst KwdPar where
    msubst (KwdPar n t e p)         = KwdPar n <$> msubst t <*> msubst e <*> msubst p
    msubst (KwdSTAR n t)            = KwdSTAR n <$> msubst t
    msubst KwdNIL                   = return KwdNIL
    
    tyfree (KwdPar n t e p)         = tyfree t ++ tyfree p
    tyfree (KwdSTAR n t)            = tyfree t
    tyfree KwdNIL                   = []

instance Subst Expr where
    msubst e                        = return e
    tyfree e                        = []

instance Subst Decl where
    msubst d@(Protocol l n q bs ss)     = do (s,ren) <- msubstRenaming d
                                             return $ Protocol l n (subst s (subst ren q)) (subst s (subst ren bs)) (subst s (subst ren ss))
    msubst d@(Class l n q bs ss)        = do (s,ren) <- msubstRenaming d
                                             return $ Class l n (subst s (subst ren q)) (subst s (subst ren bs)) (subst s (subst ren ss))
    msubst d@(Extension l n q bs ss)    = do (s,ren) <- msubstRenaming d
                                             return $ Extension l n (subst s (subst ren q)) (subst s (subst ren bs)) (subst s (subst ren ss))
    msubst d@(Def l n q p k a ss dec)   = do (s,ren) <- msubstRenaming d
                                             return $ Def l n (subst s (subst ren q)) (subst s (subst ren p)) (subst s (subst ren k))
                                                              (subst s (subst ren a)) (subst s (subst ren ss)) dec
    msubst d@(Actor l n q p k a ss)     = do (s,ren) <- msubstRenaming d
                                             return $ Actor l n (subst s (subst ren q)) (subst s (subst ren p)) (subst s (subst ren k))
                                                                (subst s (subst ren a)) (subst s (subst ren ss))

    tybound (Protocol l n q bs ss)  = tybound q
    tybound (Class l n q bs ss)     = tybound q
    tybound (Extension l n q bs ss) = tybound q
    tybound (Def l n q p k a ss d)  = tybound q
    tybound (Actor l n q p k a ss)  = tybound q
    
    tyfree (Protocol l n q bs ss)   = nub (tyfree q ++ tyfree bs ++ tyfree ss) \\ tybound q
    tyfree (Class l n q bs ss)      = nub (tyfree q ++ tyfree bs ++ tyfree ss) \\ tybound q
    tyfree (Extension l n q bs ss)  = nub (tyfree q ++ tyfree bs ++ tyfree ss) \\ tybound q
    tyfree (Def l n q p k a ss d)   = nub (tyfree q ++ tyfree p ++ tyfree k ++ tyfree a) \\ tybound q
    tyfree (Actor l n q p k a ss)   = nub (tyfree q ++ tyfree p ++ tyfree k ++ tyfree a) \\ tybound q
    
instance Subst Stmt where
    msubst (Decl l ds)              = Decl l <$> msubst ds
    msubst (Signature l ns tsc d)   = Signature l ns <$> msubst tsc <*> return d
    msubst s                        = return s

    tyfree (Decl l ds)              = tyfree ds
    tyfree (Signature l ns tsc d)   = tyfree tsc
    tyfree s                        = []


    
-- Error handling ------------------------------------------------------------------------

data CheckerError                   = FileNotFound ModName
                                    | NameNotFound Name
                                    | NameReserved QName
                                    | NameBlocked QName
                                    | NameUnexpected QName
                                    | TypedReassign Pattern
                                    | IllegalRedef Name
                                    | IllegalExtension QName
                                    | MissingSelf Name
                                    | IllegalImport SrcLoc
                                    | DuplicateImport Name
                                    | NoItem ModName Name
                                    | NoModule ModName
                                    | NoClassOrProto QName
                                    | OtherError SrcLoc String
                                    deriving (Show)

data TypeError                      = TypeErrHmm            -- ...
                                    | RigidVariable TVar
                                    | InfiniteType TVar
                                    | ConflictingRow TVar
                                    | KwdNotFound Name
                                    | DecorationMismatch Name TSchema Decoration
                                    | EscapingVar [TVar] TSchema
                                    | NoSelStatic Name TCon
                                    | NoSelInstByClass Name TCon
                                    | NoMutProto Name
                                    | NoMutClass Name
                                    | LackSig Name
                                    | LackDef Name
                                    | NoRed Constraint
                                    deriving (Show)

instance Control.Exception.Exception TypeError
instance Control.Exception.Exception CheckerError


instance HasLoc TypeError where
    loc (RigidVariable tv)          = loc tv
    loc (InfiniteType tv)           = loc tv
    loc (ConflictingRow tv)         = loc tv
    loc (KwdNotFound n)             = loc n
    loc (DecorationMismatch n t d)  = loc n
    loc (EscapingVar tvs t)         = loc tvs
    loc (NoSelStatic n u)           = loc n
    loc (NoSelInstByClass n u)      = loc n
    loc (NoMutProto n)              = loc n
    loc (NoMutClass n)              = loc n
    loc (LackSig n)                 = loc n
    loc (LackDef n)                 = loc n
    loc (NoRed c)                   = loc c

typeError err                       = (loc err,render (expl err))
  where
    expl (RigidVariable tv)         = text "Type" <+> pretty tv <+> text "is rigid"
    expl (InfiniteType tv)          = text "Type" <+> pretty tv <+> text "is infinite"
    expl (ConflictingRow tv)        = text "Row" <+> pretty tv <+> text "has conflicting extensions"
    expl (KwdNotFound n)            = text "Keyword element" <+> quotes (pretty n) <+> text "is not found"
    expl (DecorationMismatch n t d) = text "Decoration for" <+> pretty n <+> text "does not match signature" <+> pretty (n,NSig t d)
    expl (EscapingVar tvs t)        = text "Type annotation" <+> pretty t <+> text "is too general, type variable" <+>
                                      pretty (head tvs) <+> text "escapes"
    expl (NoSelStatic n u)          = text "Static method" <+> pretty n <+> text "cannot be selected from" <+> pretty u <+> text "instance"
    expl (NoSelInstByClass n u)     = text "Instance attribute" <+> pretty n <+> text "cannot be selected from class" <+> pretty u
    expl (NoMutProto n)             = text "Protocol attribute" <+> pretty n <+> text "cannot be mutated"
    expl (NoMutClass n)             = text "Class attribute" <+> pretty n <+> text "cannot be mutated"
    expl (LackSig n)                = text "Declaration lacks accompanying signature"
    expl (LackDef n)                = text "Signature lacks accompanying definition"
    expl (NoRed c)                  = text "Cannot infer" <+> pretty c


checkerError (FileNotFound n)       = (loc n, "Type interface file not found for " ++ prstr n)
checkerError (NameNotFound n)       = (loc n, "Name " ++ prstr n ++ " is not in scope")
checkerError (NameReserved n)       = (loc n, "Name " ++ prstr n ++ " is reserved but not yet defined")
checkerError (NameBlocked n)        = (loc n, "Name " ++ prstr n ++ " is currently not accessible")
checkerError (NameUnexpected n)     = (loc n, "Unexpected variable name: " ++ prstr n)
checkerError (TypedReassign p)      = (loc p, "Type annotation on reassignment: " ++ prstr p)
checkerError (IllegalRedef n)       = (loc n, "Illegal redefinition of " ++ prstr n)
checkerError (IllegalExtension n)   = (loc n, "Illegal extension of " ++ prstr n)
checkerError (MissingSelf n)        = (loc n, "Missing 'self' parameter in definition of")
checkerError (IllegalImport l)      = (l,     "Relative import not yet supported")
checkerError (DuplicateImport n)    = (loc n, "Duplicate import of name " ++ prstr n)
checkerError (NoModule m)           = (loc m, "Module " ++ prstr m ++ " does not exist")
checkerError (NoItem m n)           = (loc n, "Module " ++ prstr m ++ " does not export " ++ nstr n)
checkerError (NoClassOrProto n)     = (loc n, "Class or protocol name expected, got " ++ prstr n)
checkerError (OtherError l str)     = (l,str)

nameNotFound n                      = Control.Exception.throw $ NameNotFound n
nameReserved n                      = Control.Exception.throw $ NameReserved n
nameBlocked n                       = Control.Exception.throw $ NameBlocked n
nameUnexpected n                    = Control.Exception.throw $ NameUnexpected n
typedReassign p                     = Control.Exception.throw $ TypedReassign p
illegalRedef n                      = Control.Exception.throw $ IllegalRedef n
illegalExtension n                  = Control.Exception.throw $ IllegalExtension n
missingSelf n                       = Control.Exception.throw $ MissingSelf n
fileNotFound n                      = Control.Exception.throw $ FileNotFound n
illegalImport l                     = Control.Exception.throw $ IllegalImport l
duplicateImport n                   = Control.Exception.throw $ DuplicateImport n
noItem m n                          = Control.Exception.throw $ NoItem m n
noModule m                          = Control.Exception.throw $ NoModule m
notClassOrProto n                   = Control.Exception.throw $ NoClassOrProto n
err l s                             = Control.Exception.throw $ OtherError l s

err1 x s                            = err (loc x) (s ++ " " ++ prstr x)
err2 (x:_) s                        = err1 x s

notYetExpr e                        = notYet (loc e) e

rigidVariable tv                    = Control.Exception.throw $ RigidVariable tv
infiniteType tv                     = Control.Exception.throw $ InfiniteType tv
conflictingRow tv                   = Control.Exception.throw $ ConflictingRow tv
kwdNotFound n                       = Control.Exception.throw $ KwdNotFound n
decorationMismatch n t d            = Control.Exception.throw $ DecorationMismatch n t d
escapingVar tvs t                   = Control.Exception.throw $ EscapingVar tvs t
noSelStatic n u                     = Control.Exception.throw $ NoSelStatic n u
noSelInstByClass n u                = Control.Exception.throw $ NoSelInstByClass n u
noMutProto n                        = Control.Exception.throw $ NoMutProto n
noMutClass n                        = Control.Exception.throw $ NoMutClass n
lackSig ns                          = Control.Exception.throw $ LackSig (head ns)
lackDef ns                          = Control.Exception.throw $ LackDef (head ns)
noRed c                             = Control.Exception.throw $ NoRed c

