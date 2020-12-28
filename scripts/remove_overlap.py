import argparse

def get_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser("Remove overlapping text")
    parser.add_argument("--train_file", action="store",
                        type=str, help="The training file")
    parser.add_argument("--test_file", action="store",
                        type=str, help="The training file")
    args = parser.parse_args()
    return args

def main(train_file: str, test_file: str) -> None:
    test = set()
    with open(test_file, "r", encoding="utf-8") as infile:
        for line in infile:
            test.add(line.strip())
    buffer = []
    dup_count = 0
    with open(train_file, "r", encoding="utf-8") as infile:
        for line in infile:
            line = line.strip()
            if line not in test:
                buffer.append(line)
            else:
                dup_count += 1
    print(f"Found {dup_count} duplicates")
    with open(train_file, "w", encoding="utf-8") as outfile:
        for line in buffer:
            outfile.write(line + "\n")

    

if __name__ == "__main__":
    args = get_arguments()
    main(args.train_file, args.test_file)
