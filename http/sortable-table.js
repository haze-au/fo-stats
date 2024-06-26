��/ * 
   *       T h i s   c o n t e n t   i s   l i c e n s e d   a c c o r d i n g   t o   t h e   W 3 C   S o f t w a r e   L i c e n s e   a t 
   *       h t t p s : / / w w w . w 3 . o r g / C o n s o r t i u m / L e g a l / 2 0 1 5 / c o p y r i g h t - s o f t w a r e - a n d - d o c u m e n t 
   * 
   *       F i l e :       s o r t a b l e - t a b l e . j s 
   * 
   *       D e s c :       A d d s   s o r t i n g   t o   a   H T M L   d a t a   t a b l e   t h a t   i m p l e m e n t s   A R I A   A u t h o r i n g   P r a c t i c e s 
   * / 
 
 ' u s e   s t r i c t ' ; 
 
 c l a s s   S o r t a b l e T a b l e   { 
     c o n s t r u c t o r ( t a b l e N o d e )   { 
         t h i s . t a b l e N o d e   =   t a b l e N o d e ; 
 
         t h i s . c o l u m n H e a d e r s   =   t a b l e N o d e . q u e r y S e l e c t o r A l l ( ' t h e a d   t h ' ) ; 
 
         t h i s . s o r t C o l u m n s   =   [ ] ; 
 
         f o r   ( v a r   i   =   0 ;   i   <   t h i s . c o l u m n H e a d e r s . l e n g t h ;   i + + )   { 
             v a r   c h   =   t h i s . c o l u m n H e a d e r s [ i ] ; 
             v a r   b u t t o n N o d e   =   c h . q u e r y S e l e c t o r ( ' b u t t o n ' ) ; 
             i f   ( b u t t o n N o d e )   { 
                 t h i s . s o r t C o l u m n s . p u s h ( i ) ; 
                 b u t t o n N o d e . s e t A t t r i b u t e ( ' d a t a - c o l u m n - i n d e x ' ,   i ) ; 
                 b u t t o n N o d e . a d d E v e n t L i s t e n e r ( ' c l i c k ' ,   t h i s . h a n d l e C l i c k . b i n d ( t h i s ) ) ; 
             } 
         } 
 
         t h i s . o p t i o n C h e c k b o x   =   d o c u m e n t . q u e r y S e l e c t o r ( 
             ' i n p u t [ t y p e = " c h e c k b o x " ] [ v a l u e = " s h o w - u n s o r t e d - i c o n " ] ' 
         ) ; 
 
         i f   ( t h i s . o p t i o n C h e c k b o x )   { 
             t h i s . o p t i o n C h e c k b o x . a d d E v e n t L i s t e n e r ( 
                 ' c h a n g e ' , 
                 t h i s . h a n d l e O p t i o n C h a n g e . b i n d ( t h i s ) 
             ) ; 
             i f   ( t h i s . o p t i o n C h e c k b o x . c h e c k e d )   { 
                 t h i s . t a b l e N o d e . c l a s s L i s t . a d d ( ' s h o w - u n s o r t e d - i c o n ' ) ; 
             } 
         } 
     } 
 
     s e t C o l u m n H e a d e r S o r t ( c o l u m n I n d e x )   { 
         i f   ( t y p e o f   c o l u m n I n d e x   = = =   ' s t r i n g ' )   { 
             c o l u m n I n d e x   =   p a r s e I n t ( c o l u m n I n d e x ) ; 
         } 
 
         f o r   ( v a r   i   =   0 ;   i   <   t h i s . c o l u m n H e a d e r s . l e n g t h ;   i + + )   { 
             v a r   c h   =   t h i s . c o l u m n H e a d e r s [ i ] ; 
             v a r   b u t t o n N o d e   =   c h . q u e r y S e l e c t o r ( ' b u t t o n ' ) ; 
             i f   ( i   = = =   c o l u m n I n d e x )   { 
                 v a r   v a l u e   =   c h . g e t A t t r i b u t e ( ' a r i a - s o r t ' ) ; 
                 i f   ( v a l u e   = = =   ' d e s c e n d i n g ' )   { 
                     c h . s e t A t t r i b u t e ( ' a r i a - s o r t ' ,   ' a s c e n d i n g ' ) ; 
                     t h i s . s o r t C o l u m n ( 
                         c o l u m n I n d e x , 
                         ' a s c e n d i n g ' , 
                         c h . c l a s s L i s t . c o n t a i n s ( ' n u m ' ) 
                     ) ; 
                 }   e l s e   { 
                     c h . s e t A t t r i b u t e ( ' a r i a - s o r t ' ,   ' d e s c e n d i n g ' ) ; 
                     t h i s . s o r t C o l u m n ( 
                         c o l u m n I n d e x , 
                         ' d e s c e n d i n g ' , 
                         c h . c l a s s L i s t . c o n t a i n s ( ' n u m ' ) 
                     ) ; 
                 } 
             }   e l s e   { 
                 i f   ( c h . h a s A t t r i b u t e ( ' a r i a - s o r t ' )   & &   b u t t o n N o d e )   { 
                     c h . r e m o v e A t t r i b u t e ( ' a r i a - s o r t ' ) ; 
                 } 
             } 
         } 
     } 
 
     s o r t C o l u m n ( c o l u m n I n d e x ,   s o r t V a l u e ,   i s N u m b e r )   { 
         f u n c t i o n   c o m p a r e V a l u e s ( a ,   b )   { 
             i f   ( s o r t V a l u e   = = =   ' a s c e n d i n g ' )   { 
                 i f   ( a . v a l u e   = = =   b . v a l u e )   { 
                     r e t u r n   0 ; 
                 }   e l s e   { 
                     i f   ( i s N u m b e r )   { 
                         r e t u r n   a . v a l u e   -   b . v a l u e ; 
                     }   e l s e   { 
                         r e t u r n   a . v a l u e   <   b . v a l u e   ?   - 1   :   1 ; 
                     } 
                 } 
             }   e l s e   { 
                 i f   ( a . v a l u e   = = =   b . v a l u e )   { 
                     r e t u r n   0 ; 
                 }   e l s e   { 
                     i f   ( i s N u m b e r )   { 
                         r e t u r n   b . v a l u e   -   a . v a l u e ; 
                     }   e l s e   { 
                         r e t u r n   a . v a l u e   >   b . v a l u e   ?   - 1   :   1 ; 
                     } 
                 } 
             } 
         } 
 
         i f   ( t y p e o f   i s N u m b e r   ! = =   ' b o o l e a n ' )   { 
             i s N u m b e r   =   f a l s e ; 
         } 
 
         v a r   t b o d y N o d e   =   t h i s . t a b l e N o d e . q u e r y S e l e c t o r ( ' t b o d y ' ) ; 
         v a r   r o w N o d e s   =   [ ] ; 
         v a r   d a t a C e l l s   =   [ ] ; 
 
         v a r   r o w N o d e   =   t b o d y N o d e . f i r s t E l e m e n t C h i l d ; 
 
         v a r   i n d e x   =   0 ; 
         w h i l e   ( r o w N o d e )   { 
             r o w N o d e s . p u s h ( r o w N o d e ) ; 
             v a r   r o w C e l l s   =   r o w N o d e . q u e r y S e l e c t o r A l l ( ' t h ,   t d ' ) ; 
             v a r   d a t a C e l l   =   r o w C e l l s [ c o l u m n I n d e x ] ; 
 
             v a r   d a t a   =   { } ; 
             d a t a . i n d e x   =   i n d e x ; 
             d a t a . v a l u e   =   d a t a C e l l . t e x t C o n t e n t . t o L o w e r C a s e ( ) . t r i m ( ) ; 
             i f   ( i s N u m b e r )   { 
                 d a t a . v a l u e   =   p a r s e F l o a t ( d a t a . v a l u e ) ; 
             } 
             d a t a C e l l s . p u s h ( d a t a ) ; 
             r o w N o d e   =   r o w N o d e . n e x t E l e m e n t S i b l i n g ; 
             i n d e x   + =   1 ; 
         } 
 
         d a t a C e l l s . s o r t ( c o m p a r e V a l u e s ) ; 
 
         / /   r e m o v e   r o w s 
         w h i l e   ( t b o d y N o d e . f i r s t C h i l d )   { 
             t b o d y N o d e . r e m o v e C h i l d ( t b o d y N o d e . l a s t C h i l d ) ; 
         } 
 
         / /   a d d   s o r t e d   r o w s 
         f o r   ( v a r   i   =   0 ;   i   <   d a t a C e l l s . l e n g t h ;   i   + =   1 )   { 
             t b o d y N o d e . a p p e n d C h i l d ( r o w N o d e s [ d a t a C e l l s [ i ] . i n d e x ] ) ; 
         } 
     } 
 
     / *   E V E N T   H A N D L E R S   * / 
 
     h a n d l e C l i c k ( e v e n t )   { 
         v a r   t g t   =   e v e n t . c u r r e n t T a r g e t ; 
         t h i s . s e t C o l u m n H e a d e r S o r t ( t g t . g e t A t t r i b u t e ( ' d a t a - c o l u m n - i n d e x ' ) ) ; 
     } 
 
     h a n d l e O p t i o n C h a n g e ( e v e n t )   { 
         v a r   t g t   =   e v e n t . c u r r e n t T a r g e t ; 
 
         i f   ( t g t . c h e c k e d )   { 
             t h i s . t a b l e N o d e . c l a s s L i s t . a d d ( ' s h o w - u n s o r t e d - i c o n ' ) ; 
         }   e l s e   { 
             t h i s . t a b l e N o d e . c l a s s L i s t . r e m o v e ( ' s h o w - u n s o r t e d - i c o n ' ) ; 
         } 
     } 
 } 
 
 / /   I n i t i a l i z e   s o r t a b l e   t a b l e   b u t t o n s 
 w i n d o w . a d d E v e n t L i s t e n e r ( ' l o a d ' ,   f u n c t i o n   ( )   { 
     v a r   s o r t a b l e T a b l e s   =   d o c u m e n t . q u e r y S e l e c t o r A l l ( ' t a b l e . s o r t a b l e ' ) ; 
     f o r   ( v a r   i   =   0 ;   i   <   s o r t a b l e T a b l e s . l e n g t h ;   i + + )   { 
         n e w   S o r t a b l e T a b l e ( s o r t a b l e T a b l e s [ i ] ) ; 
     } 
 } ) ; 
 
