// Queue implementation //////////////////////////////////////////////////////////////////

None enqueue($ROWLISTHEADER lst, $ROW elem) {
  if (lst->last)
    lst->last->next = elem;
  else
    lst->fst = elem;
  lst->last = elem;
}

// Hashable$PREFIX ////////////////////////////////////////////////////////////////////////

$bool Hashable$PREFIX_eq(Hashable$PREFIX wit, $PREFIX a, $PREFIX b) {
  if (a->prefix_size != b->prefix_size)
    return $false;
  for (int i=0; i< a->prefix_size; i++)
    if (a->prefix[i] != b->prefix[i])
      return $false;
  return $true;
}

$bool Hashable$PREFIX_ne(Hashable$PREFIX wit, $PREFIX a, $PREFIX b) {
  return to$bool( !from$bool(Hashable$PREFIX_eq(wit,a,b)));
}

$int Hashable$PREFIX_hash(Hashable$PREFIX wit, $PREFIX a) {
  return to$int($PREFIX_hash(a));
}


static struct Hashable$PREFIX$__class__ Hashable$PREFIX_methods = {"",Hashable$PREFIX_eq,Hashable$PREFIX_ne,Hashable$PREFIX_hash};
static struct Hashable$PREFIX Hashable$PREFIX_instance = {"",&Hashable$PREFIX_methods};
static Hashable$PREFIX Hashable$PREFIX_witness = &Hashable$PREFIX_instance;

 
Hashable$PREFIX Hashable$PREFIX_new() {
  return Hashable$PREFIX_witness;
}

// Hashable$Word (for pointers) ////////////////////////////////////////////////////////////////////////

$bool Hashable$WORD_eq(Hashable$WORD wit, $WORD a, $WORD b) {
  return to$bool(a==b);
}

$bool Hashable$WORD_ne(Hashable$WORD wit, $WORD a, $WORD b) {
  return  to$bool(a != b);
}

$int Hashable$WORD_hash(Hashable$WORD wit, $WORD a) {
  return to$int(pointer_hash(a));
}


static struct Hashable$WORD$__class__ Hashable$WORD_methods = {"",Hashable$WORD_eq,Hashable$WORD_ne,Hashable$WORD_hash};
static struct Hashable$WORD Hashable$WORD_instance = {"",&Hashable$WORD_methods};
static Hashable$WORD Hashable$WORD_witness = &Hashable$WORD_instance;

 
Hashable$WORD Hashable$WORD_new() {
  return Hashable$WORD_witness;
}

// Serialization methods ///////////////////////////////////////////////////////////////////////////////

void write_serialized($ROW row, char *file) {
  char buf[BUF_SIZE];
  char *p = buf;
  char *bufend = buf + BUF_SIZE;
  FILE *fileptr = fopen(file,"wb");
  int chunk_size;
  char *start;
  while(row) {
    
    chunk_size = 3*sizeof(int);
    start = (char*)row;
    if (p+chunk_size > bufend) {
      int fits = bufend - p;
      memcpy(p,start,fits);
      fwrite(buf,1,sizeof(buf),fileptr); // TODO:  handle file write error
      p = buf;
      chunk_size -= fits;
      start += fits;
    }
    memcpy(p,start,chunk_size);
    p+=chunk_size;
    
    chunk_size = (row->prefix_size+row->blob_size)*sizeof($WORD);
    start =  (char*)row->data;
    while (p+chunk_size > bufend) {
      int fits = bufend - p;
      memcpy(p,start,fits);
      fwrite(buf,1,sizeof(buf),fileptr); // TODO:  handle file write error
      p = buf;
      chunk_size -= fits;
      start += fits;
    }
    memcpy(p,start,chunk_size);
    p+=chunk_size;
    
    row = row->next;
  }
  fwrite(buf,1,p-buf,fileptr); // TODO:  handle file write error
  fclose(fileptr);
}
 
$ROW serialize(Serializable s, long prefix[], int prefix_size) {
  $ROWLISTHEADER accum = malloc(sizeof(struct $ROWLISTHEADER));
  accum->fst = NULL;
  accum->last = NULL;
  $dict done = $new_dict((Hashable)Hashable$WORD_new());
  s->__class__->__serialize__(s,($WORD*)prefix,prefix_size,done,accum);
  return accum->fst;
}

void serialize_file(Serializable s, long prefix[], int prefix_size, char *file) {
  write_serialized(serialize(s,prefix,prefix_size),file);
}

Serializable deserialize($ROW row, long *prefix, int *prefix_size) {
  serial$_methods[INT_ID] = (serial$__methods__)$int_methods;
  serial$_methods[FLOAT_ID] = (serial$__methods__)$float_methods;
  serial$_methods[STR_ID] = (serial$__methods__)$str_methods;
  serial$_methods[BOOL_ID] = (serial$__methods__)$bool_methods;
  serial$_methods[LIST_ID] = (serial$__methods__)$list_methods;
  serial$_methods[DICT_ID] = (serial$__methods__)$dict_methods;
  serial$_methods[SET_ID] = (serial$__methods__)$set_methods;
  memcpy(prefix,row->data,row->prefix_size*sizeof($WORD));
  *prefix_size = row->prefix_size;
  $dict done = $new_dict((Hashable)Hashable$PREFIX_new());
  return serial$_methods[row->class_id]->__deserialize__(&row,done);
}

$ROW read_serialized(char *file) {
  char buf[BUF_SIZE];
  char *p = buf;
  char *bufend;
  FILE *fileptr = fopen(file,"rb");
  int chunk_size;
  char *start;
  struct $ROWLISTHEADER header;
  header.fst = NULL;
  header.last = NULL;
  bufend = buf + fread(buf,1,sizeof(buf),fileptr);
  while(p < bufend || !feof(fileptr)) {
    int init[3];
    chunk_size = 3*sizeof(int);
    start = (char*)init;
    if (p + chunk_size > bufend) {
      int fits = bufend - p;
      memcpy(start,p,fits);
      bufend = buf + fread(buf,1,sizeof(buf),fileptr); // TODO:  handle file write error
      p = buf;
      chunk_size -= fits;
      start += fits;
    }
    memcpy(start,p,chunk_size);
    p+=chunk_size;
    $ROW row = malloc(3*sizeof(int) + (init[1]+init[2]+1) * sizeof($WORD));
    memcpy(row,init,3*sizeof(int));
    row->next = NULL;
    chunk_size =  (init[1]+init[2]) * sizeof($WORD);
    start = (char*)row->data;
    while (p + chunk_size > bufend) {
      int fits = bufend - p;
      memcpy(start,p,fits);
      bufend = buf + fread(buf,1,sizeof(buf),fileptr); // TODO:  handle file write error
      p = buf;
      chunk_size -= fits;
      start += fits;
    }
    memcpy(start,p,chunk_size);
    p+=chunk_size;
    enqueue(&header,row);
  }
  return header.fst;
}
       
Serializable deserialize_file(char *file,  long *prefix, int *prefix_size) {
  return deserialize(read_serialized(file),prefix,prefix_size);
}


$ROW new_row(int class_id, int prefix_size, int blob_size, $WORD *prefix) {
  $ROW res = malloc(3 * sizeof(int) + (1+prefix_size+blob_size)*sizeof($WORD));
  res->class_id = class_id;
  res->prefix_size = prefix_size;
  res->blob_size = blob_size;
  res->next = 0;
  memcpy(res->data,prefix,prefix_size*sizeof($WORD));
  return res;
}
  
Hashable Hashable_instance(long class_id) {
  switch (class_id) {
  case INT_ID:
    return (Hashable)Hashable$int_new();
  case FLOAT_ID:
    return (Hashable)Hashable$float_new();
  case STR_ID:
    return (Hashable)Hashable$str_new();
  default:
    fprintf(stderr,"Can't find Hashable instance for class_id %ld\n",class_id);
    exit(1);
  }
}
