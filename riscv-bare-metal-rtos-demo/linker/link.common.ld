SEARCH_DIR(.)
__DYNAMIC  =  0;

ENTRY(_start)
MEMORY
{
    BRAM    : ORIGIN = 0x80000000, LENGTH = 0x00100000
}

/* Stack information variables */
_min_stack      = 0x2000;   /* 2K - minimum stack space to reserve */


SECTIONS
{
	PROVIDE(__boot_address = 0x80010000);
	PROVIDE(__vectors_address = 0x80000800);
	
    .vectors __vectors_address :
    {
        KEEP(*(.vectors))
        . = ALIGN(4);
    } > BRAM
    
    .trap_handler __boot_address :
    {
		*(.trap_handler.start)
		*(.trap_handler)
  	} > BRAM
  
    .text : {
        _common_memory_begin = .;
        . = ALIGN(4);
        _stext = .;
        *(.text)
        _etext  =  .;
        __CTOR_LIST__ = .;
        LONG((__CTOR_END__ - __CTOR_LIST__) / 4 - 2)
        *(.ctors)
        LONG(0)
        __CTOR_END__ = .;
        __DTOR_LIST__ = .;
        LONG((__DTOR_END__ - __DTOR_LIST__) / 4 - 2)
        *(.dtors)
        LONG(0)
        __DTOR_END__ = .;
        *(.lit)
        *(.shdata)
        _endtext = .;
    }  > BRAM

    /*--------------------------------------------------------------------*/
    /* Global constructor/destructor segement                             */
    /*--------------------------------------------------------------------*/

    .preinit_array     :
    {
      PROVIDE_HIDDEN (__preinit_array_start = .);
      KEEP (*(.preinit_array))
      PROVIDE_HIDDEN (__preinit_array_end = .);
    } > BRAM

    .init_array     :
    {
      PROVIDE_HIDDEN (__init_array_start = .);
      KEEP (*(SORT(.init_array.*)))
      KEEP (*(.init_array ))
      PROVIDE_HIDDEN (__init_array_end = .);
    } > BRAM

    .fini_array     :
    {
      PROVIDE_HIDDEN (__fini_array_start = .);
      KEEP (*(SORT(.fini_array.*)))
      KEEP (*(.fini_array ))
      PROVIDE_HIDDEN (__fini_array_end = .);
    } > BRAM

    .rodata : {
        . = ALIGN(4);
        *(.rodata);
        *(.rodata.*)
    } > BRAM

    .shbss :
    {
        . = ALIGN(4);
        *(.shbss)
    } > BRAM

    .data : {
        . = ALIGN(4);
        sdata  =  .;
        _sdata  =  .;
        *(.data);
        *(.data.*)
        edata  =  .;
        _edata  =  .;
    } > BRAM

    .bss :
    {
        . = ALIGN(4);
        _bss_start = .;
        *(.bss)
        *(.bss.*)
        *(.sbss)
        *(.sbss.*)
        *(COMMON)
        _bss_end = .;
    } > BRAM

    .stab  0 (NOLOAD) :
    {
        [ .stab ]
    }

    .stabstr  0 (NOLOAD) :
    {
        [ .stabstr ]
    }
    
    .bss :
    {
        _common_memory_end = .;
        . = ALIGN(4);
        _end = .;
    } > BRAM
    
    .privileged_functions : ALIGN(1024) {
        *(.priv_functions);
        *(.priv_functions.*)
    } > BRAM

    .privileged_data : ALIGN(1024) {
        *(.priv_data);
        *(.priv_data.*)
    } > BRAM
    
    /* ensure there is enough room for stack */
    .stack : 
    {
        _stack_start = .;
    	_stack = . ;
        . = ALIGN(4);
        . = . + _min_stack ;
        . = ALIGN(4);
        stack = . ;
    } > BRAM

    .task1_text : ALIGN(1024)
    {
        . = ALIGN(4);
        __task1_text_begin = .;
        *(.task1_text)
        . = ALIGN(4); 
        __task1_text_end = .;
    } > BRAM

    .task2_text : ALIGN(1024)
    {
        . = ALIGN(4);
        __task2_text_begin = .;
        *(.task2_text)
        . = ALIGN(4);
        __task2_text_end = .;
    } > BRAM


    .task_stacks : ALIGN(1024)
    {
        . = ALIGN(1024);
        __task1_stack_begin = .;
        *(.task1_stack)
        __task1_stack_end = .;
        . = ALIGN(1024);
        __task2_stack_begin = .;
        *(.task2_stack)
        __task2_stack_end = .;

    } > BRAM

}
