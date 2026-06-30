import sys

def count_braces(filepath):
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        content = f.read()
        
    p_count = 0 # ()
    b_count = 0 # {}
    s_count = 0 # []
    
    in_string = False
    in_comment = False
    in_m_comment = 0 # /* */
    
    i = 0
    while i < len(content):
        c = content[i]
        
        # Handle string
        if not in_comment and in_m_comment == 0:
            if c == '"':
                if i > 0 and content[i-1] == '@': # Verbatim string
                    in_string = not in_string
                elif in_string:
                    # check for escape
                    esc_count = 0
                    j = i - 1
                    while j >= 0 and content[j] == '\\':
                        esc_count += 1
                        j -= 1
                    if esc_count % 2 == 0:
                        in_string = False
                else:
                    in_string = True
        
        if not in_string:
            # Handle comments
            if not in_comment and in_m_comment == 0:
                if c == '-' and i+1 < len(content) and content[i+1] == '-':
                    in_comment = True
                    i += 1
                elif c == '/' and i+1 < len(content) and content[i+1] == '*':
                    in_m_comment += 1
                    i += 1
            elif in_comment:
                if c == '\n':
                    in_comment = False
            elif in_m_comment > 0:
                if c == '*' and i+1 < len(content) and content[i+1] == '/':
                    in_m_comment -= 1
                    i += 1
                elif c == '/' and i+1 < len(content) and content[i+1] == '*':
                    in_m_comment += 1
                    i += 1
                    
            if not in_comment and in_m_comment == 0:
                if c == '(': p_count += 1
                if c == ')': p_count -= 1
                if c == '{': b_count += 1
                if c == '}': b_count -= 1
                if c == '[': s_count += 1
                if c == ']': s_count -= 1
        
        i += 1
        
    print(f"Braces Summary for {filepath}:")
    print(f"Parentheses (): {p_count}")
    print(f"Braces {{}}: {b_count}")
    print(f"Square Brackets []: {s_count}")

if __name__ == "__main__":
    count_braces(sys.argv[1])
