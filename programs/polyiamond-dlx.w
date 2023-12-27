\datethis
@s box int
@s node int

@*Intro. This program produces a {\mc DLX} file that corresponds to the
problem of packing a given set of polyiamonds into a given two-dimensional box.
The output file might be input directly to a {\mc DLX}-solver; however,
it often is edited manually, to customize a particular problem
(for example, to avoid producing solutions that are equivalent
to each other). (I hacked this from {\mc POLYOMINO-DLX}.)

The triangular cells in the box are of two kinds, $\Delta$ and $\nabla$.
Both kinds have two coordinates $xy$, in the range $0\le x,y<62$,
specified by means of the extended hexadecimal ``digits''
\.0, \.1, \dots,~\.9, \.a, \.b, \dots,~\.z, \.A, \.B, \dots,~\.Z.
The `$\nabla$' triangles, which appear immediately to the right of
their `$\Delta$' counterparts, are distinguished by having an apostrophe
following the coordinates. (It may be helpful to think of a square cell
$xy$, which has been subdivided into right triangles $xy$ and $xy'$ by its main
diagonal, then slightly squashed so that the triangles become equilateral.)

As in {\mc DLX} format, any line of |stdin| that begins with `\.{\char"7C}' is
considered to be a comment.

The first noncomment line specifies the cells of the box. It's a
list of pairs $xy$ or $xy'$, where each coordinate is either
a single digit or a set of digits enclosed in square brackets. For example,
`\.{[02]b}' specifies two cells, \.{0b}, \.{2b}.
Brackets may also contain a range of items, with UNIX-like conventions;
for instance, `\.{[0-2][b-b]'}' specifies three cells,
\.{0b'}, \.{1b'}, \.{2b'}. A $3\times4$ parallelogram, which contains
24 triangles, can be specified by
`\.{[1-3][1-4]} \.{[1-3][1-4]'}'.

{\it Note:}\enspace With square cells we had the luxury of regarding the pair $xy$
in either of two ways:
(i)~``matrixwise'' (with $x$ denoting a row and $y$ a column;
increasing $x$ meant going down, while increasing $y$ meant going right);
or (ii)~``Cartesianwise'' (with $x$ and $y$ denoting horizontal and vertical
displacement; increasing $x$ meant going right, while increasing $y$
meant going up). However, with triangular cells, we're totally Cartesian.

Individual cells may be specified more than once, but they appear
just once in the box. For example,
$$\.{[123]2}\qquad \.{2[123]} \.{[12][12]'}$$
specifies a noniamond that looks something like a fish.
The cells of a box needn't be connected.

Cell specifications can optionally be followed by a suffix. For example,
`\.{[12]7suf}' specifies two items named `\.{17suf}' and `\.{27suf}'.
Such items will be {\it secondary}, unless the suffix is simply `\.''.

The other noncomment lines consist of a piece name followed by typical
cells of that piece. These typical cells are specified in the same way
as the cells of a box.

The typical cells lead to up to 12 ``base placements'' for a given piece,
corresponding to rotations and/or reflections in two-dimensional space.
The piece can then be placed by choosing one of its base placements and shifting
it by an arbitrary amount, provided that all such cells fit in the box.
The base placements themselves need not fit in the box.

All suffixes associated with a cell will be appended to the items
generated by that cell. For example, a piece that has typical cells
`\.{00}, \.{00'}, \.{00!}, \.{00'!}' will generate options for every
pair of adjacent cells in the box: When \.{33'} and \.{34} are present,
there will be an option `\.{33'} \.{34} \.{33'!} \.{34!}'.
If \.{00'!} hadn't been specified, there
would have been {\it two\/} options, `\.{33'} \.{34} \.{33'!}' and
`\.{34} \.{33'} \.{34!}'.

Each piece name should be distinguishable from the coordinates of the cells
in the box. (For example, a piece should not be named \.{00} unless cell
\.{00} isn't in the box.) This condition is not fully checked by the program.

A piece that is supposed to occur more than once can be preceded by its
multiplicity and a vertical line; for example, one can give its name
as `\.{12\char"7C Z}'. (This feature will produce a file that can be handled
only by {\mc DLX} solvers that allow multiplicity.)

Several lines may refer to the same piece. In such cases the placements
from each line are combined.

@ OK, here we go.

@d bufsize 1024 /* input lines shouldn't be longer than this */
@d maxpieces 100 /* at most this many pieces */
@d maxnodes 100000 /* at most this many elements of lists */
@d maxbases 1000 /* at most this many base placements */
@d maxsuffixes 10 /* at most this many suffixes */

@c
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
char buf[bufsize];
@<Type definitions@>;
@<Global variables@>;
@<Subroutines@>;
main () {
  register int i,j,k,p,q,r,t,x,y,dx,dy,xy0,suf;
  register long long xa,ya;
  @<Read the box spec@>;
  @<Read the piece specs@>;
  @<Output the {\mc DLX} item-name line@>;
  @<Output the {\mc DLX} options@>;
  @<Bid farewell@>;
}

@* Low-level operations.
I'd like to begin by building up some primitive subroutines that will help
to parse the input and to publish the output.

For example, I know that
I'll need basic routines for the input and output of radix-62 digits.

@<Sub...@>=
int decode(char c) {
  if (c<='9') {
    if (c>='0') return c-'0';
  }@+else if (c>='a') {
    if (c<='z') return c+10-'a';
  }@+else if (c>='A' && c<='Z') return c+36-'A';
  if (c!='\n') return -1;
  fprintf(stderr,"Incomplete input line: %s",
                                         buf);
  exit(-888);
}
@#
char encode(int x) {
  if (x<0) return '-';
  if (x<10) return '0'+x;
  if (x<36) return 'a'-10+x;
  if (x<62) return 'A'-36+x;
  return '?';
}

@ I'll also want to decode the specification of a given {\it set\/} of digits,
starting at position |p| in |buf|.
Subroutine |pdecode| sets the global variable
|acc| to a 64-bit number that represents the digit or digits mentioned there.
Then it returns the next buffer position, so that I can continue scanning.

@<Sub...@>=
int pdecode(register int p) {
  register int x;
  if (buf[p]!='[') {
    x=decode(buf[p]);
    if (x>=0) {
      acc=1LL<<x;
      return p+1;
    }
    fprintf(stderr,"Illegal digit at position %d of %s",
                                     p,buf);
    exit(-2);
  }@+else @<Decode a bracketed specification@>;
}

@ We want to catch illegal syntax such as `\.{[-5]}', `\.{[1-]}',
`\.{[3-2]}', `\.{[1-2-3]}', `\.{[3--5]}',
while allowing `\.{[7-z32-4A5-5]}', etc.
(The latter is equivalent to `\.{[2-57-A]}'.)

Notice that the empty specification `\.{[]}' is legal, but useless.

@<Decode a bracketed specification@>=
{
  register int t,y;
  for (acc=0,t=x=-1,p++;buf[p]!=@q[@>']';p++) {
    if (buf[p]=='\n') {
      fprintf(stderr,"No closing bracket in %s",
                                           buf);
      exit(-4);
    }
    if (buf[p]=='-') @<Get ready for a range@>@;
    else {
      x=decode(buf[p]);
      if (x<0) {
        fprintf(stderr,"Illegal bracketed digit at position %d of %s",
                                               p,buf);
        exit(-3);
      }
      if (t<0) acc|=1LL<<x;
      else @<Complete the range from |t| to |x|@>;
    }
  }
  return p+1;  
}

@ @<Get ready for a range@>=
{
  if (x<0 || buf[p+1]==@q[@>']') {
    fprintf(stderr,"Illegal range at position %d of %s",
                                              p,buf);
    exit(-5);
  }
  t=x, x=-1;
}  

@ @<Complete the range from |t| to |x|@>=
{
  if (x<t) {
    fprintf(stderr,"Decreasing range at position %d of %s",
                                               p,buf);
    exit(-6);
  }
  acc|=(1LL<<(x+1))-(1LL<<t);
  t=x=-1;
}

@ @<Glob...@>=
long long acc; /* accumulated bits representing coordinate numbers */
long long accx,accy; /* the bits for each dimension of a partial spec */

@* Data structures.
The given box is remembered as a sorted list of cells $xy$, represented as
a linked list of packed integers |(x<<8)+y|.
The base placements of each piece are also remembered in the same way.

All of the relevant information appears in a structure of type |box|.

@<Type def...@>=
typedef struct {
  int list; /* link to the first of the packed triples $xy$ */
  int size; /* the number of items in that list */
  int xmin,xmax,ymin,ymax; /* extreme coordinates */
  int pieceno; /* the piece, if any, for which this is a base placement */
} box;

@ Elements of the linked lists appear in structures of type |node|.

All of the lists will be rather short. So I make no effort to devise
methods that are asymptotically efficient as things get infinitely large.
My main goal is to have a program that's simple and correct.
(And I hope that it will also be easy and fun to read, when I need to
refer to it or modify it.)

@<Type def...@>=
typedef struct {
  int xy; /* position data stored in this node */
  int suf; /* suffix data for this node */
  int link; /* the next node of the list, if any */
} node;

@ All of the nodes appear in the array |elt|. I allocate it statically,
because it doesn't need to be very big.

@<Glob...@>=
node elt[maxnodes]; /* the nodes */
int curnode; /* the last node that has been allocated so far */
int avail; /* the stack of recycled nodes */

@ Subroutine |getavail| allocates a new node when needed.

@<Sub...@>=
int getavail(void) {
  register int p=avail;
  if (p) {
    avail=elt[avail].link;
    return p;
  }
  p=++curnode;
  if (p<maxnodes) return p;
  fprintf(stderr,"Overflow! Recompile me by making maxnodes bigger than %d.\n",
                             maxnodes);
  exit(-666);
}

@ Conversely, |putavail| recycles a list of nodes that are no longer needed.

@<Sub...@>=
void putavail(int p) {
  register int q;
  if (p) {
    for (q=p; elt[q].link; q=elt[q].link) ;
    elt[q].link=avail;
    avail=p;
  }
}

@ The |insert| routine puts new $(x,y)$ data into the list of |newbox|,
unless $(x,y)$ is already present.

@<Sub...@>=
void insert(int x,int y,int s) {
  register int p,q,r,xy;
  xy=(x<<8)+y;
  for (q=0,p=newbox.list;p;q=p,p=elt[p].link) {
    if (elt[p].xy==xy) {
      if (elt[p].suf==s) return; /* nothing to be done */
      if (elt[p].suf>s) break; /* we've found the insertion point */
    }@+else if (elt[p].xy>xy) break; /* we've found the insertion point */
  }
  r=getavail();
  elt[r].xy=xy, elt[r].suf=s, elt[r].link=p;
  if (q) elt[q].link=r;
  else newbox.list=r;
  newbox.size++;
  if (x<newbox.xmin) newbox.xmin=x;
  if (y<newbox.ymin) newbox.ymin=y;
  if (x>newbox.xmax) newbox.xmax=x;
  if (y>newbox.ymax) newbox.ymax=y;
}

@ Although this program is pretty simple, I do want to watch it in operation
before I consider it to be reasonably well debugged. So here's a
subroutine that's useful for diagnostic purposes.

@<Sub...@>=
void printbox(box*b) {
  register int p,x,y;
  fprintf(stderr,"Piece %d, size %d, %d..%d %d..%d:\n",
                       b->pieceno, b->size, b->xmin, b->xmax,
                                                b->ymin, b->ymax);
  for (p=b->list;p;p=elt[p].link) {
    x=elt[p].xy>>8, y=elt[p].xy&0xff;
    fprintf(stderr," %c%c%s",
                    encode(x),encode(y),elt[p].suf?suffix[elt[p].suf-1]:"");
  }
  fprintf(stderr,"\n");
}

@*Inputting the given box. Now we're ready to look at the $xy$ specifications
of the box to be filled. As we read them, we remember the cells in
the box called |newbox|. Then, for later convenience, we also record
them in a three-dimensional array called |occupied|.

@ @<Read the box spec@>=
while (1) {
  if (!fgets(buf,bufsize,stdin)) {
    fprintf(stderr,"Input file ended before the box specification!\n");
    exit(-9);
  }
  if (buf[strlen(buf)-1]!='\n') {
    fprintf(stderr,"Overflow! Recompile me by making bufsize bigger than %d.\n",
                             bufsize);
    exit(-667);
  }
  printf("| %s",
                   buf); /* all input lines are echoed as DLX comments */
  if (buf[0]!='|') break;
}
p=0;
@<Put the specified cells into |newbox|, starting at |buf[p]|@>;
givenbox=newbox;
@<Set up the |occupied| table@>;

@ This spec-reading code will also be useful later when I'm inputting the
typical cells of a piece.

@<Put the specified cells into |newbox|, starting at |buf[p]|@>=
newbox.list=newbox.size=0;
newbox.xmin=newbox.ymin=62;
newbox.xmax=newbox.ymax=-1;
for (;buf[p]!='\n';p++) {
  if (buf[p]!=' ') @<Scan an $xy$ spec@>;
}

@ I could make this faster by using bitwise trickery. But what the heck.

@<Scan an $xy$ spec@>=
{
  p=pdecode(p),accx=acc;
  p=pdecode(p),accy=acc;
  @<Digest the optional suffix, |suf|@>;
  if (buf[p]=='\n') p--; /* we'll reread the newline character */
  for (x=0,xa=accx;xa;x++,xa>>=1) if (xa&1) {
    for (y=0,ya=accy;ya;y++,ya>>=1) if (ya&1)
      insert(x,y,suf);
  }
}

@ Suffixes will be stored in pairs, both with and without `\.'' at the front.

@<Digest the optional suffix, |suf|@>=
for (q=0;buf[p+q]!=' ' && buf[p+q]!='\n';q++) {
  if (q==6) {
    fprintf(stderr,"Suffix too long, starting at position %d of %s",
                                p,buf);
    exit(-11);
  }
  suffix[scount][q]=buf[p+q];
}
if (q) {
  suffix[scount][q]=0;
  p+=q;
  for (i=0;;i++) if (strcmp(suffix[i],suffix[scount])==0) break;
  if (i==scount) {
    scount+=2;
    if (scount>maxsuffixes) {
      fprintf(stderr,"Overflow! Recompile me by making maxsuffixes>%d.\n",
                                    maxsuffixes);
      exit(-7);
    }
    if (suffix[i][0]=='\'')
      strcpy(suffix[scount-1],suffix[i]),
      strcpy(suffix[i],&suffix[scount-1][1]),i++;
    else {
      strcpy(&suffix[scount-1][1],suffix[i]),suffix[scount-1][0]='\'';
      if (strlen(suffix[scount-1])>6) {
        fprintf(stderr,"Implied suffix `%s' is too long!\n",
                                       suffix[scount-1]);
        exit(-9);
      }
    }
  }
  suf=i+1;
}@+else suf=0;

@ @<Set up the |occupied| table@>=
for (p=givenbox.list;p;p=elt[p].link) {
  x=elt[p].xy>>8, y=elt[p].xy&0xff;
  occupied[elt[p].suf][x][y]=1;
}

@ @<Glob...@>=
box newbox; /* the current specifications are placed here */
char suffix[maxsuffixes+1][8]={"\'"}; /* table of suffixes seen */
int scount=1; /* this many nonempty suffixes seen */
char occupied[maxsuffixes+1][64][64]; /* does the box occupy a given cell? */
box givenbox;
int sfxpresent; /* this many items in |givenbox| have suffixes */

@*Inputting the given pieces. After I've seen the box, the remaining
noncomment lines of the input file are similar to the box line, except
that they begin with a piece name.

This name can be any string of one to eight nonspace characters
allowed by {\mc DLX} format, followed by a space. It should also
not be the same as a position of the box.

I keep a table of the distinct piece names that appear, and their
multiplicities.

And of course I also compute and store all of the base placements that
correspond to the typical cells that are specified.

@<Glob...@>=
char names[maxpieces][8]; /* the piece names seen so far */
int piececount; /* how many of them are there? */
char mult[maxpieces][8]; /* what is the multiplicity? */
char multip[8]; /* current multiplicity */
box base[maxbases]; /* the base placements seen so far */
int basecount; /* how many of them are there? */

@ @<Read the piece specs@>=
while (1) {
  if (!fgets(buf,bufsize,stdin)) break;
  if (buf[strlen(buf)-1]!='\n') {
    fprintf(stderr,
        "Overflow! Recompile me by making bufsize bigger than %d.\n",
                           bufsize);
    exit(-777);
  }
  printf("| %s",
                   buf); /* all input lines are echoed as DLX comments */
  if (buf[0]=='|') continue;
  @<Read a piece spec@>;
}

@ @<Read a piece spec@>=
@<Read the piece name, and find it in the |names| table at position |k|@>;
newbox.pieceno=k; /* now |buf[p]| is the space following the name */
@<Put the specified cells into |newbox|, starting at |buf[p]|@>;
@<Normalize the cells of |newbox|@>;
base[basecount]=newbox;
@<Create the other base placements equivalent to |newbox|@>;

@ We accept any string of characters followed by `\.{\char"7C}' as a multiplicity.

@ @<Read the piece name, and find it in the |names| table at position |k|@>=
for (p=0;buf[p]!='\n';p++) if (buf[p]=='|') break; else multip[p]=buf[p];
if (buf[p]=='|') multip[p]='\0',p++;
else p=0,multip[0]='1',multip[1]='\0';
for (q=p;buf[p]!='\n';p++) {
  if (buf[p]==' ') break;
  if (buf[p]=='|' || buf[p]==':') {
    fprintf(stderr,"Illegal character in piece name: %s",
                                          buf);
    exit(-8);
  }
}
if (buf[p]=='\n') {
  fprintf(stderr,"(Empty %s is being ignored)\n",
              p==0? "line": "piece");
  continue;
}
@<Store the name in |names[piececount]| and check its validity@>;
for (k=0;;k++) if (strncmp(names[k],names[piececount],8)==0) break;
if (k==piececount) { /* it's a new name */
  if (++piececount>maxpieces) {
    fprintf(stderr,
       "Overflow! Recompile me by making maxpieces bigger than %d.\n",
                             maxpieces);
    exit(-668);
  }
}
if (!mult[k][0]) strcpy(mult[k],multip);
else if (strcmp(mult[k],multip)) {
  fprintf(stderr,"Inconsistent multiplicities for piece %.8s, %s vs %s!\n",
               names[k],mult[k],multip);
  exit(-6);
}

@ @<Store the name in |names[piececount]| and check its validity@>=
if (p==q || p>q+8) {
  fprintf(stderr,"Piece name is nonexistent or too long: %s",
                                             buf);
  exit(-7);
}
for (j=q;j<p;j++) names[piececount][j-q]=buf[j];
if (p==q+2) {
  x=decode(names[piececount][0]);
  y=decode(names[piececount][1]);
  if (x>=0 && y>=0 && occupied[0][x][y]) {
    fprintf(stderr,"Piece name conflicts with board position: %s",
                                   buf);
    exit(-333);
  }
}

@ It's a good idea to ``normalize'' the typical cells of a piece,
by making the |xmin| and |ymin| fields of |newbox| both zero.

@<Normalize the cells of |newbox|@>=
xy0=(newbox.xmin<<8)+newbox.ymin;
if (xy0) {
  for (p=newbox.list;p;p=elt[p].link) elt[p].xy-=xy0;
  newbox.xmax-=newbox.xmin,newbox.ymax-=newbox.ymin;
  newbox.xmin=newbox.ymin=0;
}

@*Transformations. Now we get to the interesting part of this program,
as we try to find all of the base placements that are obtainable from
a given set of typical cells.

The method is a simple application of breadth-first search:
Starting at the newly created base, we make sure that
every elementary transformation of every known placement is also known.

This procedure requires a simple subroutine to check whether or not
two placements are equal. We can assume that both placements are normalized,
and that both have the same size. Equality testing is easy because
the lists have been sorted.

@<Sub...@>=
int equality(int b) { /* return 1 if |base[b]| matches |newbox| */
  register int p,q;
  for (p=base[b].list,q=newbox.list; p; p=elt[p].link,q=elt[q].link)
    if (elt[p].xy!=elt[q].xy || elt[p].suf!=elt[q].suf) return 0;
  return 1;
}

@ Just two elementary transformations suffice to generate them all.
These transformations depend (in a somewhat subtle-but-nice way) on
whether or not there's a suffix that begins with `\.''.

@<Create the other base placements equivalent to |newbox|@>=
j=basecount,k=basecount+1; /* bases |j| thru |k-1| have been checked */
while (j<k) {
  @<Set |newbox| to |base[j]| transformed by $60^\circ$ rotation@>;
  for (i=basecount;i<k;i++)
    if (equality(i)) break;
  if (i<k) putavail(newbox.list); /* already known */
  else base[k++]=newbox; /* we've found a new one */
  @<Set |newbox| to |base[j]| transformed by |xy| transposition@>;
  for (i=basecount;i<k;i++)
    if (equality(i)) break;
  if (i<k) putavail(newbox.list); /* already known */
  else base[k++]=newbox; /* we've found a new one */
  j++;
}
basecount=k;
if (basecount+12>maxbases) {
  fprintf(stderr,"Overflow! Recompile me by making maxbases bigger than %d.\n",
              basecount+23);
  exit(-669);
}

@ The first elementary transformation replaces
$(x,y)$ by $(x+y-1,1-x)'$ and
$(x,y)'$ by $(x+y,1-x)$.
It corresponds to 60-degree rotation about the
``origin'' (the point between $(0,0)'$ and $(1,1)$)
in our coordinates).

Actually I add a constant, then normalize afterwards, so that the
coordinates don't go negative.

@<Set |newbox| to |base[j]| transformed by $60^\circ$ rotation@>=
newbox.size=newbox.list=0;
t=newbox.ymax=base[j].xmax;@+newbox.xmax=0;
newbox.xmin=newbox.ymin=64;
for (p=base[j].list;p;p=elt[p].link) {
  x=elt[p].xy>>8, y=elt[p].xy&0xff;
  if (elt[p].suf&1) { /* suffix starts with prime */
    insert(x+y+1,t-x,elt[p].suf-1);
  }@+else {
    insert(x+y,t-x,elt[p].suf+1);
  }
}
@<Normalize the cells of |newbox|@>;

@ The other elementary transformation replaces $(x,y)$ by $(y,x)$ and
$(x,y)'$ by $(y,x)'$. It corresponds to reflection about the line at slope
$30^\circ$ through the origin---a nice reflection that doesn't
interchange $\Delta$ with $\nabla$.

[I like to think of the barycentric coordinates $(x,y,z)$ such that
$x+y+z=1$ or~2, with $(x,y)\leftrightarrow(x,y,2-x,y)$ and
$(x,y)'\leftrightarrow(x,y,1-x-y)$.
With such coordinates the simplest transformations take $(x,y,z)$ to
$(y,x,z)$, $(y,z,x)$, and $(1-x,1-y,1-z)$.]

@<Set |newbox| to |base[j]| transformed by |xy| transposition@>=
newbox.size=newbox.list=0;
newbox.xmax=base[j].ymax, newbox.ymax=base[j].xmax;
for (p=base[j].list;p;p=elt[p].link) {
  x=elt[p].xy>>8, y=elt[p].xy&0xff;
  insert(y,x,elt[p].suf);
}

@*Finishing up. In previous parts of this program, I've terminated
abruptly when finding malformed input.

But when everything on |stdin| passes muster,
I'm ready to publish all the information that has been gathered.

@<Output the {\mc DLX} item-name line@>=
printf("| this file was created by polyiamond-dlx from that data\n");
for (p=givenbox.list;p;p=elt[p].link) if (elt[p].suf<2) {
  x=elt[p].xy>>8, y=elt[p].xy&0xff;
  printf(" %c%c%s",
                  encode(x),encode(y),elt[p].suf?"'":"");
}
for (k=0;k<piececount;k++) {
  if (mult[k][0]=='1' && mult[k][1]=='\0')
    printf(" %.8s",
               names[k]);
  else printf(" %s|%.8s",
               mult[k],names[k]);
}
if (scount>1) {
  printf(" |");
  for (sfxpresent=0,p=givenbox.list;p;p=elt[p].link) if (elt[p].suf>1) {
    x=elt[p].xy>>8, y=elt[p].xy&0xff, sfxpresent++;
    printf(" %c%c%s",
                    encode(x),encode(y),suffix[elt[p].suf-1]);
  }
}
printf("\n");

@ @<Output the {\mc DLX} options@>=
for (j=0;j<basecount;j++) {
  for (dx=givenbox.xmin;dx<=givenbox.xmax-base[j].xmax;dx++)
   for (dy=givenbox.ymin;dy<=givenbox.ymax-base[j].ymax;dy++) {
      for (p=base[j].list;p;p=elt[p].link) {
        x=elt[p].xy>>8, y=elt[p].xy&0xff;
        if (!occupied[elt[p].suf][x+dx][y+dy]) break;
      }
      if (!p) { /* they're all in the box */
        printf("%.8s",
          names[base[j].pieceno]);
        for (p=base[j].list;p;p=elt[p].link) {
          x=elt[p].xy>>8, y=elt[p].xy&0xff;
          printf(" %c%c%s",
                  encode(x+dx),encode(y+dy),elt[p].suf?suffix[elt[p].suf-1]:"");
        }
        printf("\n");
      }
    }
}

@ Finally, when I've finished outputting the desired {\mc DLX} file,
it's time to say goodbye by summarizing what I did.

@<Bid farewell@>=
if (!sfxpresent)
  fprintf(stderr,
    "Altogether %d cells, %d pieces, %d base placements, %d nodes.\n",
      givenbox.size,piececount,basecount,curnode+1);
else fprintf(stderr,
  "Altogether %d+%d cells, %d pieces, %d base placements, %d nodes.\n",
      givenbox.size-sfxpresent,sfxpresent,piececount,basecount,curnode+1);

@ @<Subroutines@>=
void debug(int m) {
  fprintf(stderr," ..debug stop %d..\n",
                                 m);
}

@*Index.
