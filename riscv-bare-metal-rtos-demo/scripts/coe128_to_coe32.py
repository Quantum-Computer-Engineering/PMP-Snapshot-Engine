# Define the input and output file names
input_file = 'build/img/code_and_data.coe128'  # Replace with your actual input file name
output_file = 'build/img/code_and_data.coe'  # Replace with your desired output file name


def transform_file(input_file, output_file):
    skip_lines_counter = 2

    with open(input_file, 'r') as infile, open(output_file, 'w') as outfile:
        for line in infile:
            if skip_lines_counter > 0:
                skip_lines_counter -= 1
                outfile.write(line)
            else:
                # Remove any trailing whitespace or newlines
                line = line.strip()

                # Split the line into chunks of 8 characters each
                chunks = [line[i:i+8] for i in range(0, len(line)-1, 8)]

                # Write each chunk to the output file, one per line
                for chunk in chunks:
                    outfile.write(chunk + ',\n')

# Run the transformation
transform_file(input_file, output_file)
