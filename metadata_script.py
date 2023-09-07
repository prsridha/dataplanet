import os
import hashlib
import json
import argparse

def calculate_md5(file_path):
    """Calculate the MD5 checksum for a given file."""
    md5 = hashlib.md5()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(8 * 1024 * 1024), b''):
            md5.update(chunk)
    return md5.hexdigest()

def get_file_size(filepath):
    try:
        # Get the file size in bytes
        file_size = os.path.getsize(filepath)
        return file_size
    except FileNotFoundError:
        return "File not found"
    except Exception as e:
        return f"An error occurred: {str(e)}"


def main():
    parser = argparse.ArgumentParser(description="Generate a JSON file with a list of file information.")
    parser.add_argument("directory", help="The directory to process")

    args = parser.parse_args()

    if not os.path.isdir(args.directory):
        print("Invalid directory path.")
        return

    file_list = []
    for filename in os.listdir(args.directory):
        filepath = os.path.join(args.directory, filename)
        if os.path.isfile(filepath):
            d = {
                "filename": filename,
                "filesize": get_file_size(filepath),
                "md5sum": calculate_md5(filepath)
            }
            file_list.append(d)

    output_file = "{}_file_metadata.json".format(args.directory.split("/")[-1])
    with open(output_file, "w") as json_file:
        json.dump(file_list, json_file, indent=4)

    print(f"File list saved to {output_file}.")

if __name__ == "__main__":
    main()
