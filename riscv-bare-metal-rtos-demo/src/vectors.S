.section .vectors, "ax"
.option norvc
vector_table:
	j trap_handler_asm
	j handle_external_interrupt
	j handle_external_interrupt
	j major_alert_exception
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	# j timer_interrupt // Together with trap_handler_asm because it is so similar (saves context)
	j trap_handler_asm
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
	j handle_external_interrupt
