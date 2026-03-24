import hashlib
import os

# === 輸入多筆測資（Test ID, ASCII內容） ===
test_vectors = [
    ("tv0", ""),
    ("tv1", "abcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcda"),
    ("tv2", "abcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdab"),
    ("tv3", "abcdabcdbabcdbacbdabcdbacbdabcdabcdbacdbacbdbacdbacdabc"),
    ("tv4", "abcdefabcdabacdbacdbacdadbcbadcbacbdabcdabcacbdabcdaabcd"),
    ("tv5", "abcdefgaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
    ("tv6", "abcdbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbab"),
    ("tv7", "abcdabcdabcdcabdbcadcaacccccccccccccccccccccccccccccccccabc"),
    ("tv8", "abcdabbbbbbbbbchadbchacdadcacdachjbauijaaaaaaaaaccccccdcabcd"),
    ("tv9", "abcdeabhchajbcabcbaidbcjahdbcjabcabcdhbajcdbhabkdcbhjadcabcda"),
    ("tv10", "abcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdab"),
    ("tv11", "abcdefgahdjbvchjabdcjhabdjchagjdcvajhdbjhcabdjhcbajhdsvgjabaabc"),
    ("tv12", "abcdefgahdjbvchjabdcjhabdjchagjdcvajhdbjhcabdjhcbajhdsvgjabaabcd"),
    ("tv13", "0000000000000000000000000000000000000000000000000000000000000000"),
    ("tv14", "a"),
    ("tv15", "ab"),
    ("tv16", "abc"),
    ("tv17", "abcd"),
    ("tv18", "abcde"),
    ("tv19", "abcdef"),
    ("tv20", "abcdefg"),
    ("tv21", "abcdefgh"),
    ("tv22", "abcdefghi"),
    ("tv23", "abcdefghij"),
    ("tv24", "abcdefghijk"),
    ("tv25", "abcdefgahdjbvchjabdcjhabdjchagjdcvajhdbjhcabdjhcbajhdsvgjabaabcda"),
    ("tv26", ""),
    ("tv27", "abcdefgahdjbvchjabdcjhabdjchagjdcvajhdbjhcabdjhcbajhdsvgjabaabcdaiurtunbpoiefmbvoixdjnfnfdoubndfiubvndlrogsdliubvnxifdutnboudsfnbolsdbpiunbliuesrnvsedisunboidshb9pestnhpoesjfvsernvpoesrjviuerbviuyerthb3hg8ong9phfnfiuyerbvpobwauyfbnewoiyciouawenfoiuesrbvoiuestrnhbooerngopisenrofinseroiugnsetrpoibnoisuenboiudrbordngoiesnhfiuenbrkuygberofneafnaiebwfoaewnfliuarwbiufyb3uyfb wariufbwaeuyrb fiuyeabfoiu34nfiuyebrvliubeariuvnbaeiybviauenbvciusenfiuerbviuesbviuesrbvieabrviubaiuecbisenvckidsf viserbviuernbfouaebvieanviu dib iusanbciuswnecpoq2h98d3hjr8hfo357fo48hgppppgwru4gvoierubviuenrvoinsodfvnseirvnsfvnslkdufbvliskeugfhbliwrgbvnlesrkvbiusetrnuoirstjbpoiertjmbprtnoriteunseuroivnserjfiserjngiuwemrogroisjlsdjvme,prmjngfmeernbvuyinviefnvoiudsnvoiurtnvoiusehbvlsiuerbgslkrugblutbnselovmnsojme;rowiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiiinvpevoewbviwpnp4pwfn3498fhw348fw7b8vfpeosnvilusernboprtnbpotersmbliudfnbe"),
    ("tv28", "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq"),
    ("tv29", "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
     ]

# === 輸出資料夾 ===
output_dir = "./all_vectors"
os.makedirs(output_dir, exist_ok=True)

# === 資料儲存用 ===
all_dat = []
all_be = []
all_lst = []
all_len = []
all_golden_256 = []
summary_rows = []

word_counter = 0  # 用來追蹤 address

for test_id, user_input_str in test_vectors:
    input_bytes = user_input_str.encode("utf-8")
    digest_hex = hashlib.sha256(input_bytes).hexdigest()  # 64 hex = 256-bit
    total_len = len(input_bytes)
    msg_len_bits = total_len * 8

    word_list = []
    msg_be_list = []
    msg_lst_list = []

    # === 分割成 32-bit words（4 bytes 為一組）===
    i = 0
    while i < total_len:
        chunk = input_bytes[i:i+4]
        word = int.from_bytes(chunk.ljust(4, b'\x00'), 'big')
        word_list.append(f"{word:08x}")

        be_mask = {
            1: 0b1000,
            2: 0b1100,
            3: 0b1110,
            4: 0b1111
        }.get(len(chunk), 0)
        msg_be_list.append(f"{be_mask:X}")
        i += 4

    # === msg_lst：最後一筆為 1，其餘為 0 ===
    for i in range(len(word_list)):
        msg_lst_list.append("1" if i == len(word_list) - 1 else "0")

    msg_len_hex = f"{msg_len_bits:016x}"

    # === 組合輸出資料（含地址）===
    for i in range(len(word_list)):
        all_dat.append(f"@{word_counter:07x} {word_list[i]}")
        all_be.append(f"@{word_counter:07x} {msg_be_list[i]}")
        all_lst.append(f"@{word_counter:07x} {msg_lst_list[i]}")
        word_counter += 1

    all_len.append(f"@{len(all_len):07x} {msg_len_hex}")
    all_golden_256.append(f"@{len(all_golden_256):07x} {digest_hex}")

    summary_rows.append({
        "Test ID": test_id,
        "Input": user_input_str,
        "Input Bytes": total_len,
        "msg_len(bits)": msg_len_bits,
        "Words": len(word_list),
        "Digest (256-bit HEX)": digest_hex
    })

# === 寫入檔案 ===
def write_file(path, lines):
    with open(path, "w") as f:
        f.write("\n".join(lines))

write_file(f"{output_dir}/test_vec.dat", all_dat)
write_file(f"{output_dir}/msg_be.dat", all_be)
write_file(f"{output_dir}/msg_lst.dat", all_lst)
write_file(f"{output_dir}/msg_len.dat", all_len)
write_file(f"{output_dir}/gold_vec.dat", all_golden_256)

# === 顯示摘要 ===
print(f"✅ 所有檔案已輸出至：{output_dir}")
for row in summary_rows:
    print(f"- {row['Test ID']}: \"{row['Input']}\" → {row['msg_len(bits)']} bits, {row['Words']} words")

