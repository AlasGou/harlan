(library
  (harlan middle compile-module)
  (export compile-module)
  (import (rnrs) (except (elegant-weapons helpers) ident?)
    (harlan helpers))

(define-match compile-module
  ((module ,[(compile-decl #f) -> typedef* decl*] ...)
   `((include "harlan.hpp") ,@(apply append typedef*)
     . ,(apply append decl*))))

;; This also lifts the typedefs to the top, so that we can construct
;; mutually recursive structures.
(define-match (compile-decl in-kernel?)
  ((fn ,name ,args (,arg-types -> ,ret-type)
     ,[(compile-stmt in-kernel?) -> stmt])
   (let ((arg-types (if in-kernel?
                        arg-types
                        (map (lambda (t) (if (equal? t '(ptr region))
                                        '(ref (ptr region))
                                        t))
                             arg-types)))
         (ret-type (if in-kernel?
                       ret-type
                       (if (equal? ret-type '(ptr region))
                           '(ref (ptr region))
                           ret-type))))
     (values '() `((func ,ret-type ,name ,(map list args arg-types) ,stmt)))))
  ((extern ,name ,arg-types -> ,rtype)
   (values '() `((extern ,rtype ,name ,arg-types))))
  ((global ,type ,name ,[(compile-expr in-kernel?) -> e])
   (values '() `((global ,type ,name ,e))))
  ((typedef ,name ,t)
   (values `((typedef ,name ,t)) '()))
  ((gpu-module ,[compile-kernel -> typedef* kernel*] ...)
   (values '() `((gpu-module ,@(apply append typedef*)
                             . ,(apply append kernel*))))))

(define-match compile-kernel
  ((kernel ,name ,args ,[(compile-stmt #t) -> stmt])
   (values '() `((kernel ,name ,args ,stmt))))
  (,else ((compile-decl #t) else)))

(define-match (compile-stmt in-kernel?)
  ((begin ,[stmt*] ...)
   `(begin . ,stmt*))
  ((let ,x ,t ,[(compile-expr in-kernel?) -> e])
   `(let ,x ,t ,e))
  ((let ,x ,t)
   `(let ,x ,t))
  ((if ,[(compile-expr in-kernel?) -> test] ,[conseq])
   `(if ,test ,conseq))
  ((if ,[(compile-expr in-kernel?) -> test] ,[conseq] ,[alt])
   `(if ,test ,conseq ,alt))
  ((print ,[(compile-expr in-kernel?) -> expr] ...) `(print . ,expr))
  ((return) `(return))
  ((return ,[(compile-expr in-kernel?) -> expr]) `(return ,expr))
  ((assert ,[(compile-expr in-kernel?) -> expr]) `(do (assert ,expr)))
  ((set! ,[(compile-expr in-kernel?) -> x] ,[(compile-expr in-kernel?) -> e])
   `(set! ,x ,e))
  ((while ,[(compile-expr in-kernel?) -> expr] ,[stmt])
   `(while ,expr ,stmt))
  ((for (,i ,[(compile-expr in-kernel?) -> start]
            ,[(compile-expr in-kernel?) -> end]
            ,[(compile-expr in-kernel?) -> step])
     ,[stmt*] ...)
   `(for (,i ,start ,end ,step) . ,stmt*))
  ((error ,x) `(do (call (var harlan_error) (str ,(symbol->string x)))))
  ((do ,[(compile-expr in-kernel?) -> e]) `(do ,e)))

(define-match (compile-expr in-kernel?)
  ((,t ,n) (guard (scalar-type? t)) `(,t ,n))
  ((var ,t ,x) `(var ,x))
  ((c-expr ,t ,x) `(c-expr ,x))
  ((alloc ,[region] ,[size])
   (if in-kernel?
       `(call (c-expr alloc_in_region) ,region ,size)
       `(call (c-expr alloc_in_region) (addressof ,region) ,size)))
  ((region-ref ,t ,[region] ,[ptr])
   `(cast ,t (call (c-expr get_region_ptr) ,region ,ptr)))
  ((vector-ref ,t ,[v] ,[i]) `(vector-ref ,v ,i))
  ((if ,[test] ,[conseq] ,[alt])
   `(if ,test ,conseq ,alt))
  ((sizeof ,t) `(sizeof ,t))
  ((deref ,[e]) `(deref ,e))
  ((empty-struct) '(empty-struct))
  ((addressof ,[e]) `(addressof ,e))
  ((cast ,t ,[e]) `(cast ,t ,e))
  ((not ,[e]) `(not ,e))
  ((,op ,[e1] ,[e2])
   (guard (or (binop? op) (relop? op)))
   `(,op ,e1 ,e2))
  ((time) '(nanotime))
  ((field ,[e] ,x) `(field ,e ,x))
  ((field ,[obj] ,x ,t) `(field ,obj ,x ,t))
  ((call ,[f] ,[a*] ...) `(call ,f . ,a*)))

;; end library
)
