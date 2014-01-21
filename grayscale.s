#VERSION:	Versión 1.0. Este código ya se puede entregar.
#PURPOSE:    	This program converts a given color image file to grayscale
#	     	and saves the result in a file specified as one of the command
#	     	line parameters.
#
#PROCESSING: 	1) Verifies command line parameters, and if necessary,
#		exits with the appropiate return code (1).
#		2) Opens the input file sent through the commad line.
#		if a problema occurs, it exits with the appropiate
#		return code (2)
#		3) Opens the input file sent through the commad line.
#		if a problema occurs, it exits with the appropiate
#		return code (3)
#		4) Verifies that the magic value P6 is present, and 
#		if necessary, exits with the appropiate return code (4).

#***********************************************************************************************************************************************[DATA]

	.section .data  
	
#******************************************************************************************************************************************[CONSTANTS]

	#Options for open
	.equ O_RDONLY, 0            	    	#Open file options - read-only
	.equ O_CREAT_WRONLY_TRUNC, 03101     	#Open file options - these options are:
	                                      	#CREAT - create file if it doesn't exist
	                                      	#WRONLY - we will only write to this file
	                                      	#TRUNC - destroy current file contents, if any exist

	#System call numbers
	.equ EXIT, 1
	.equ READ, 3
	.equ WRITE, 4
	.equ OPEN, 5
	.equ CLOSE, 6	

	#System call interrupt
	.equ LINUX_SYSCALL, 0x80

	#end-of-file result status
	.equ END_OF_FILE, 0			#This is the return value of read() which
	                     			#means we've hit the end of the file

#********************************************************************************************************************************************[BUFFERS]

.section .bss
	#This is where the header is loaded into from
	#the input file and written from into the output file.
	.equ BUFFER_HEADER_SIZE, 17
	.lcomm BUFFER_HEADER, BUFFER_HEADER_SIZE

	.equ BUFFER_IMAGE_SIZE, 666
	.lcomm BUFFER_IMAGE, BUFFER_IMAGE_SIZE


#***************************************************************************************************************************************[PROGRAM CODE]

	.section .text

	#STACK POSITIONS
	.equ ST_SIZE_RESERVE, 12
	.equ ST_FD_IN, 0
	.equ ST_FD_OUT, 4
	.equ ST_SIZE_READ, 8
	.equ ST_TOTAL_ARGS, 12	#Number of arguments
	.equ ST_ARGV_0, 16   	#Name of program
	.equ ST_ARGV_1, 20   	#Input file name
	.equ ST_ARGV_2, 24   	#Output file name

	.globl _start
_start:
#*********************************************************************************************************************************[INITIALIZE PROGRAM]
	subl  $ST_SIZE_RESERVE, %esp       	#Allocate space for our pointers on the stack
	movl  %esp, %ebp

	###VERIFY ARGUMENTS IN COMMAND LINE###
	movl ST_TOTAL_ARGS(%ebp), %ebx		#Put number of arguments in %ebx
	cmpl $3, %ebx				#Total number of arguments for this program is 3
	jne exit_code_1

#**************************************************************************************************************************************[OPENING FILES]
	###OPEN INPUT FILE###
open_fd_in:
	movl  ST_ARGV_1(%ebp), %ebx  		#input filename into %ebx
	movl  $O_RDONLY, %ecx        		#read-only flag
	movl  $0666, %edx            
	movl  $OPEN, %eax            		#open syscall
	int   $LINUX_SYSCALL         		#call Linux

	###LOOK FOR ERRORS OPENING INPUT FILE###
	cmpl $0, %eax				#We use 0 since all error are negative
						#numbers and we don't want a 0 either.
						
	jle exit_code_2				#Compare with what %eax got in return.
						#Go to the correct case if needed.
	
store_fd_in:
	###STORING THE FILE DESCRIPTOR###
	movl  %eax, ST_FD_IN(%ebp)   		#save the given file descriptor

open_fd_out:
	###OPEN OUTPUT FILE###
	movl  ST_ARGV_2(%ebp), %ebx        	#output filename into %ebx
	movl  $O_CREAT_WRONLY_TRUNC, %ecx  	#flags for writing to the file
	movl  $0666, %edx                  	#permission set for new file
	movl  $OPEN, %eax                  	#open the file
	int   $LINUX_SYSCALL               	#call Linux

	###LOOK FOR ERRORS OPENING OUTPUT FILE###
	cmpl $0, %eax				#We use 0 since all error are negative
						#numbers and we don't want a 0 either.
						
	jle exit_code_3				#Compare with what %eax got in return.
						#Go to the correct case if needed.

store_fd_out:
	movl  %eax, ST_FD_OUT(%ebp)       	#Store the file descriptor here

#****************************************************************************************************************************************[HEADER WORK]
	###READ IN A HEADER FROM THE INPUT FILE###
	movl  ST_FD_IN(%ebp), %ebx     		#Get the input file descriptor
	movl  $BUFFER_HEADER, %ecx       	#The location to read into
	movl  $BUFFER_HEADER_SIZE, %edx       	#The size of the buffer
	movl  $READ, %eax
	int   $LINUX_SYSCALL           		#Size of buffer read is
	                               		#returned in %eax

	###LOOK FOR ERRORS OPENING INPUT FILE###
	cmpl $0, %eax				#We use 0 since all error are negative
						#numbers and we don't want a 0 either.
						
	jle exit_code_2				#Compare with what %eax got in return.
						#Go to the correct case if needed.

	###VERIFY MAGIC VALUE###

	#Get the "P" byte
	movl  $BUFFER_HEADER, %eax		#Put read header in %eax
	movl  $0, %ebx				#Put position of P in %ebx
	movb  (%eax,%ebx,1), %cl		#Get byte where P is expected to be
	cmpb  $80, %cl				#Compare what we read with P's ASCII value
	jne exit_code_4				#Jump to exit code 4 if P wasn't found
	
	#Get the "6" byte
	movl  $1, %ebx				#Put position of 6 in %ebx
	movb  (%eax,%ebx,1), %cl		#Get byte where P is expected to be
	cmpb  $54, %cl				#Compare what we read with P's ASCII value
	jne exit_code_4				#Jump to exit code 4 if P wasn't found

	#Get the "LF" byte
	movl  $2, %ebx				#Put position of first LF in %ebx
	movb  (%eax,%ebx,1), %cl		#Get byte where P is expected to be
	cmpb  $10, %cl				#Compare what we read with P's ASCII value
	jne exit_code_4				#Jump to exit code 4 if P wasn't found	

	###WRITE THE HEADER OUT TO THE OUTPUT FILE###
	movl  ST_FD_OUT(%ebp), %ebx	        #File to use
	movl  $BUFFER_HEADER, %ecx     		#Location of the buffer
	movl  $BUFFER_HEADER_SIZE, %edx         #Size of the buffer
	movl  $WRITE, %eax
	int   $LINUX_SYSCALL

	###LOOK FOR ERRORS WRITING TO OUTPUT FILE###
	cmpl $0, %eax				#We use 0 since all error are negative
						#numbers and we don't want a 0 either.
						
	jle exit_code_3				#Compare with what %eax got in return.
						#Go to the correct case if needed.

#*****************************************************************************************************************************************[IMAGE WORK]

read_loop_begin:
	###READ IN A BLOCK FROM THE INPUT FILE###
	movl  ST_FD_IN(%ebp), %ebx     		#Get the input file descriptor
	movl  $BUFFER_IMAGE, %ecx       	#The location to read into
	movl  $BUFFER_IMAGE_SIZE, %edx       	#The size of the buffer
	movl  $READ, %eax
	int   $LINUX_SYSCALL           		#Size of buffer read is
	                               		#Returned in %eax

	
	
	###EXIT IF WE'VE REACHED THE END###
	cmpl  $END_OF_FILE, %eax		#Check if the size of buffer read is 0
	jle   exit_code_0              		#If buffer size is 0, go to the end

	###GET %edi READY###
	movl  $0, %edi

continue_read_loop:
	###SET UP VARIABLES###
	movl  $BUFFER_IMAGE, %ebx		#Place buffer of image data in %ebx 
						#of %eax because we'll need to divide
	movl  %eax, ST_SIZE_READ(%ebp)       	#Store the size of buffer read here
	movl  $0, %eax				#Clear %eax
	movl  $0, %ecx				#Clear %ecx
	movl  $0, %edx				#Clear %edx
	

	movb  (%ebx,%edi,1), %dl
	

	incl  %edi				#Increase %edi
	movb  (%ebx,%edi,1), %cl		#Get second byte and accumulate in %eax
	addl  %edx, %ecx			#Accumulate in %eax

	incl  %edi				#Increase %edi
	movb  (%ebx,%edi,1), %al		#Get third byte
	addl  %ecx, %eax			#Accumulate in %eax

	movl  $3, %ecx				#We'll use %ecx to divide %eax
	movl  $0, %edx				#Clearing %edx
	divb  %cl				#Divide and conquer!

	###"Grayzify" the pixels###
	movb  %al, (%ebx,%edi,1)		#Modify the third pixel
	decl  %edi				#Decrease %edi
	movb  %al, (%ebx,%edi,1)		#Modify the second pixel
	decl  %edi				#Decrease %edi
	movb  %al, (%ebx,%edi,1)		#Modify the second pixel

	###CONTINUE THE LOOP###
	addl  $3, %edi				#Make %edi point to the start of
						#the next pixel
	movl  ST_SIZE_READ(%ebp), %eax       	#Recover size of buffer read
	cmpl  %eax, %edi			#If %edi is equal or higher than
	jge   time_to_write			#the buffer size, we need to write the buffer

	jmp   continue_read_loop		#Otherwise, just go and keep editing the buffer

time_to_write:
	###WRITE THE BLOCK OUT TO THE OUTPUT FILE###
	movl  ST_FD_OUT(%ebp), %ebx    		#File to use
	movl  $BUFFER_IMAGE, %ecx       	#Location of the buffer
	movl  ST_SIZE_READ(%ebp), %edx	  	#Size of the buffer
	movl  $WRITE, %eax
	int   $LINUX_SYSCALL

	###LOOK FOR ERRORS WRITING TO OUTPUT FILE###
	cmpl $0, %eax				#We use 0 since all error are negative
						#numbers and we don't want a 0 either.
						
	jle exit_code_3				#Compare with what %eax got in return.
						#Go to the correct case if needed.
	
	jmp read_loop_begin			#Now, we go and get a new buffer

#*****************************************************************************************************************************************[EXIT CODES]
	###EXIT IF NO PROBLEMS WERE FOUND###
exit_code_0:
	###CLOSE THE FILES###
	movl  ST_FD_OUT(%ebp), %ebx
	movl  $CLOSE, %eax
	int   $LINUX_SYSCALL

	movl  ST_FD_IN(%ebp), %ebx
	movl  $CLOSE, %eax
	int   $LINUX_SYSCALL

	###EXIT###
	movl  $0, %ebx
	movl  $EXIT, %eax
	int   $LINUX_SYSCALL

	###EXIT IF COMMAND LINE ARGUMENTS ARE INCORRECT###
exit_code_1:
	movl  $1, %ebx
	movl  $EXIT, %eax
	int   $LINUX_SYSCALL

	###EXIT IF THERE ARE ERRORS WITH INPUT FILE###
exit_code_2:
	###CLOSE THE INPUT FILE###
	movl  ST_FD_IN(%ebp), %ebx
	movl  $CLOSE, %eax
	int   $LINUX_SYSCALL
	
	###EXIT###	
	movl  $2, %ebx
	movl  $EXIT, %eax
	int   $LINUX_SYSCALL

	###EXIT IF THERE ARE ERRORS WITH INPUT FILE###
exit_code_3:
	###CLOSE THE FILES###
	movl  ST_FD_OUT(%ebp), %ebx
	movl  $CLOSE, %eax
	int   $LINUX_SYSCALL

	movl  ST_FD_IN(%ebp), %ebx
	movl  $CLOSE, %eax
	int   $LINUX_SYSCALL
	
	###EXIT###	
	movl  $3, %ebx
	movl  $EXIT, %eax
	int   $LINUX_SYSCALL

	###EXIT IF THERE ARE ERRORS WITH OUTPUT FILE###
exit_code_4:
	###CLOSE THE FILES###
	movl  ST_FD_OUT(%ebp), %ebx
	movl  $CLOSE, %eax
	int   $LINUX_SYSCALL

	movl  ST_FD_IN(%ebp), %ebx
	movl  $CLOSE, %eax
	int   $LINUX_SYSCALL
	
	###EXIT###	
	movl  $4, %ebx
	movl  $EXIT, %eax
	int   $LINUX_SYSCALL
