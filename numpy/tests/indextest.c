#include "../../builtin/builtin.h"
#include "../numpy.h"

int main() {
  $ndarray v = $ndarray_arange(to$int(60),NULL,NULL);
  $list newshape = $NEW($list,NULL,NULL);
  $list_append(newshape,to$int(3));
  $list_append(newshape,to$int(4));
  $list_append(newshape,to$int(5));
  $ndarray a = $ndarray_reshape(v,newshape);
  $printobj("a=",a);
  $list ix = $NEW($list,NULL,NULL);
  $list_append(ix,NULL);
  $Slice s1 = $NEW($Slice,NULL,NULL,NULL);
  $list_append(ix,s1);
  $list_append(ix,to$int(2));
  $ndarray b = $ndarray_getslice(a,ix);
  $printobj("b=",b);
  $list ix1 = $NEW($list,NULL,NULL);
  $list_append(ix1,to$int(1));
  $Slice s2 = $NEW($Slice,to$int(1),NULL,NULL);
  $list_append(ix1,s2);
  $Slice s3 = $NEW($Slice,to$int(-1),to$int(0),to$int(-1));
  $list_append(ix1,s3);
  $ndarray c = $ndarray_getslice(a,ix1);
  $printobj("c=",c);
  $list test = $list_copy(c->shape);
  $Primitive wit = ($Primitive)$Primitive$int$witness;
  $ndarray d = $ndarray_abs(wit,c);
  $printobj("d=",d);
  $ndarray e = $ndarray_fromatom(($Super)to$int(3));
  $printobj("e.shape =",e->shape);
  $printobj("e.strides =",e->strides);
  $printobj("e=",e);
  $Integral$ndarray wit2 = $NEW( $Integral$ndarray,wit);
  $ndarray f = wit2->$class->__add__(wit2,d,e);
  $printobj("f=",f);  
  $ndarray g = wit2->$class->__add__(wit2,a,e);
  $printobj("g.shape =",g->shape);
  $printobj("g.strides",g->strides);
  $printobj("g=",g);  
}
