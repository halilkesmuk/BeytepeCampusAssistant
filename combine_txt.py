import os

def combine_txt_files(input_folder, output_file):
    with open(output_file, 'w', encoding='utf-8') as outfile:
        for filename in sorted(os.listdir(input_folder)):
            if filename.endswith('.txt'):
                file_path = os.path.join(input_folder, filename)
                with open(file_path, 'r', encoding='utf-8') as infile:
                    outfile.write(f"===== {filename} =====\n")
                    outfile.write(infile.read())
                    outfile.write('\n\n')

if __name__ == "__main__":
    combine_txt_files('rag-docs-tr', 'tr-combined.txt')
