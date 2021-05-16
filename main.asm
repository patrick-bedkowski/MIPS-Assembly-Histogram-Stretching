.data

buffor:		.space 	4000			# amount of space for data
inputFile:	.space	127			# space for input file name
outputFile:	.space	127			# space for output file name

# MESSAGES #
inputMess:	.asciiz "Write input file name with .bmp extension: "
outputMess:	.asciiz "Write output file name with .bmp extension: "

minPixel:	.asciiz "Min pixel value: "
maxPixel:	.asciiz "\nMax pixel value: "
lutValue:	.asciiz "\nLUT value: "

inputOpened:	.asciiz "Input image has been opened successfuly.\n"
inputError:	.asciiz "Input image not found!"
outputError:	.asciiz "Output filename cannot be empty!"
outputDone1:	.asciiz "New image "
outputDone2:	.asciiz " has been generated successfuly.\n"

		# |-----------------------------|
		# |	 TABLE OF CONTENTS	|	
		# |-----------------------------|
		
# $s0 = Input file descriptor
# $s1 = LUT value
# $s2 = Data offset
# $s3 = Number of data sets to load from inserted file
# $s4 = MIN pixel
# $s5 = MAX pixel
# $s7 = Output file descriptor

.text
		# |-----------------------------|
		# |	GET INPUT FILE NAME	|	
		# |-----------------------------|
	
	li	$v0, 4				# display message to insert file name
	la	$a0, inputMess			# address of string to print
	syscall
	
	li	$v0, 8				# read string
	la	$a0, inputFile			# address of input buffer
	li	$a1, 127			# maximum number of characters to read
	syscall
	
searchEndLine_1:
	lb	$t0, ($a0)			# load character from inserted string
	addiu 	$a0, $a0, 1			# select next character
	bne	$t0, '\n', searchEndLine_1	# if endline char not found, check next char
	
	addi	$a0, $a0, -1			# set $a0 to the previous char
	sb	$zero, ($a0)			# replace the newline char with zero
	
		# |-----------------------------|
		# |	GET OUTPUT FILE NAME	|	
		# |-----------------------------|
	
	li	$v0, 4				# display message to insert file name
	la	$a0, outputMess		
	syscall
	
	li	$v0, 8				# read string
	la	$a0, outputFile			# address of input buffer
	li	$a1, 127			# maximum number of characters to read
	syscall
	
	# Check if user inserted an empty string
	lb	$t0, ($a0)			# load first byte from string
	beq 	$t0, '\n', outputNameError
	

searchEndLine_2:
	lb	$t0, ($a0)			# load character from inserted string
	addiu 	$a0, $a0, 1			# select next character
	bne	$t0, '\n', searchEndLine_2	# if endline char not found, check next char 
	
	addi	$a0, $a0, -1			# set $a0 to the previous char
	sb	$zero, ($a0)			# replace the newline char with zero


# Another solution for the removal of newline char
# is to use jal instructions. Using them could make
# the code more readable, but it could interrupt
# the execution of the processor pipeline

		# |-----------------------------|
		# |	OPEN IMPORTED FILE	|	
		# |-----------------------------|
		
	# openFile
	li 	$v0, 13 			# open file
	la 	$a0, inputFile			# load filename
	la	$a1, 0				# read only flag
	li   	$a2, 0
	syscall
	move	$s0, $v0 			# save imported file descriptor to $s0
	
	# check if the file has been read correctly
	blt	$s0, 0, fileOpenError		# if file descriptor less than 0 -> error
	
	# display message that the file has been opened successfuly
	li	$v0, 4		
	la	$a0, inputOpened
	syscall
	
	# openOutputFile
	li 	$v0, 13				# open output file
	la 	$a0, outputFile			# load filename
	li 	$a2, 0
	li 	$a1, 1				# set flag 
	syscall
	move 	$s7, $v0 			# save export file descriptor to $s7
	
	
	li 	$v0, 14				# read imported file
	move 	$a0, $s0			# load file descriptor
	la 	$a1, buffor			# load address of input buffer
	li 	$a2, 14				# maximum number of characters to read = header
	syscall	
	la 	$t0, buffor
	
	
	# read bmp file offset
	addiu 	$t0, $t0, 10			# move buffor
	lwr	$t1, ($t0)			# load bytes
	subiu	$s2, $t1, 14			# save offset in $s2


	# copy header to the exported file
	li	$v0, 15				# write to file
	move	$a0, $s7			# file descriptor
	la	$a1, buffor			# address of output buffer
	li	$a2, 14				# number of characters to write = header
	syscall

		# |-------------------------------------|
		# |	READ DATA FROM IMPORTED FILE	|
		# |	AND CALCULATE NUMBER OF LOOPS	|
		# |-------------------------------------|

	# readData
	# read first part of inserted file
	li	$v0, 14				# read from file
	move	$a0, $s0		
	la	$a1, buffor		
	la	$a2, 4000			# maximum number of characters to read = 4000
	syscall
	la	$t0, buffor			# load buffor to $t0
	
	# Save image size
	addiu	$t0, $t0, 20			# move buffor (14+20) bytes
	lwr	$t1, ($t0)			# number of pixels
	
	# calculate number of data sets to load
	div	$t1, $t1, 4000			# data to load divided by the portion of single load
	addiu	$s3, $t1, 1			# number of data sets to load from the inserted file


		# |-------------------------------------|
		# |	READ FIRST PIECE OF DATA	|
		# |-------------------------------------|
		
	la	$t0, buffor			# load buffor
	addu	$t0, $t0, $s2			# move about offset

	li	$t6, 3999			# number of data more to read
	subu	$t6, $t6, $s2			# counter
	lbu	$t7, ($t0)			# set current pixel to $t7
	move	$s4, $t7			# save current pixel as MIN
	move	$s5, $t7			# save current pixel as MAX
	
	move	$t4, $s3			# number of data sets
	b  	setNextPixel			# start searching for MIN/MAX pixel


		# |-------------------------------------|
		# |	SEARCH FOR MAX MIN PIXELS	|
		# |-------------------------------------|
		
loadMoreData:
	li	$v0, 14				# read from file
	move	$a0, $s0			# file descriptor
	la	$a1, buffor			# address of input buffer
	li	$a2, 4000			# maximum number of characters to read = 4000
	syscall

	li	$t6, 4000
	la	$t0, buffor

setNextPixel:
	addiu	$t0, $t0, 1			# set next pixel
	lbu	$t7, ($t0)			# set t7 as current pixel

searchMin:
	beqz	$t7, nextPixelOrEnd		# if current pixel $t7 == 0 equal to zero, go to branch
	bgt	$t7, $s4, searchMax		# if current pixel greater than MIN pixel, go to branch
	move	$s4, $t7			# if current pixel lesser/smaller than MIN pixel, set new MIN pixel


searchMax:
	blt	$t7, $s5, nextPixelOrEnd	# if current pixel lesser than MAX, jump to check next pixel
	move	$s5, $t7			# if current pixel greater than MAX pixel, set new MAX pixel


nextPixelOrEnd:
	subiu	$t6, $t6, 1			# decrease counter
	
	bgtz	$t6, setNextPixel		# if counter greater than 0
	
	subiu	$t4, $t4, 1			# decrease number of data sets to read
	bgtz	$t4, loadMoreData		# if number of data sets to read greater than 0, read more data


		# |-------------------------------------|
		# |	PRINT MIN MAX PIXELS VALUE	|
		# |-------------------------------------|

	li	$v0, 4
	la	$a0, minPixel		
	syscall
	
	li	$v0, 1
	la	$a0, ($s4)			# min pixel
	syscall
	
	li	$v0, 4
	la	$a0, maxPixel		
	syscall
	
	li	$v0, 1
	la	$a0, ($s5)			# max pixel
	syscall
	

		# |---------------------------------------------|
		# |	CALCULATE LUT VALUE			|
		# |	ACCORDING TO THE STANDARD FORMULA	|
		# |---------------------------------------------|

	li	$t3, 255			# load constant value to $t3
	sub	$t4, $s5, $s4			# the difference between MIN and MAX
	
	move 	$t5, $t3
	sll	$t5, $t3, 16			# multiply constant by 2^16
	move	$s1, $t4			# move the difference 
	sll	$s1, $t4, 6			# multiply the differency by 2^6
	div	$s1, $t5, $s1			# calculate LUT value
						# this equation can be found on the internet
						# LUT = [255*(2^16)] / [difference*(2^6)]
	
	li	$v0, 16				# close imported file
	move	$a0, $s0			# load imported file descriptor
	syscall
	
		# |-------------------------|
		# |	PRINT LUT VALUE	    |
		# |-------------------------|
	
	li	$v0, 4
	la	$a0, lutValue		
	syscall
	
	li	$v0, 1
	la	$a0, ($s1)			# LUT value
	syscall
	
	li	$v0, 11				# load new line
	la	$a0, '\n'		
	syscall

		# |-------------------------------------|
		# |	MODIFY AND SAVE PIXELS		|
		# |	TO THE EXPORTED IMAGE		|
		# |-------------------------------------|
		
		
	# READ IMPORTED FILE
	li	$v0, 13				# open file
	la	$a0, inputFile			# file name
	li	$a1, 0				# flags read only
	syscall
	
	# read header
	li	$v0, 14				# read from file
	move	$a0, $s0			# file descriptor
	la	$a1, buffor			# address of input buffer
	la	$a2, 14				# maximum number of characters to read
	syscall
	
	# read more data
	li	$v0, 14	
	move	$a0, $s0
	la	$a1, buffor
	la	$a2, 4000
	syscall
	
	la	$t0, buffor			# load buffor to $t0
	addu	$t0, $t0, $s2			# move about offset
	
	li	$t2, 4000			# set the counter to read all pixels
	subu	$t2, $t2, $s2			# decrease about offset
	
	j modifyPixel				# modify loaded pixels

readDataAgain:
	li	$v0, 14				# read from file
	move	$a0, $s0			# file descriptor
	la	$a1, buffor			# address of input buffer
	li	$a2, 4000			# maximum number of characters to read
	syscall
	li	$t2, 4000			# save buffor size to $t2
	la	$t0, buffor			# save buffor to $t0

modifyPixel:
	lbu	$t7, ($t0)			# load current pixel
	sub	$t7, $t7, $s4			# set to pixel minus MIN pixel value
	sll	$t7, $t7, 6			# multiply by 2^6
	mul	$t7, $t7, $s1			# multiply by LUT value
	sra	$t7, $t7, 16			# divide by 2^16

	sb	$t7, ($t0)			# load pixel 
	addiu	$t0, $t0, 1			# load next pixel
	subiu	$t2, $t2, 1			# decrease number of pixels to read
	bgtz	$t2, modifyPixel		# if there are still pixels to read, go to branch

		# |-------------------------------------|
		# |	SAVE MODIFIED PIXES TO FILE	|
		# |-------------------------------------|
		
	li	$v0, 15				# write to file
	move	$a0, $s7			# exported file descriptor
	la	$a1, buffor			# load modified data
	li	$a2, 4000			# maximum number of characters to read
	syscall

	subiu	$s3, $s3, 1			# decrease number of data sets to read
	bgtz	$s3, readDataAgain		# if number of data to read is greater than 0, read more data

		# |-------------------------------------|
		# |	CLOSE FILES AND END PROGRAM	|
		# |-------------------------------------|

	li	$v0, 16				# close file
	move	$a0, $s0			# load descriptor of an imported file 
	syscall

	move	$a0, $s7			# load descriptor of an exported file 
	syscall
	
	# display message of successful operation
	li	$v0, 4			
	la	$a0, outputDone1
	syscall
	
	la	$a0, outputFile
	syscall
	
	la	$a0, outputDone2
	syscall
	
	# end program
	li	$v0, 10			
	syscall				


		# |-----------------------------|
		# |	EXCEPTION HANDLING	|
		# |-----------------------------|

outputNameError:
	li	$v0, 4
	la	$a0, outputError	
	syscall
	
	# end program
	li $v0, 10			
	syscall

fileOpenError:	
	li	$v0, 4
	la	$a0, inputError	
	syscall
	
	# end program
	li $v0, 10			
	syscall
