import random
import struct

def rotr(x, n):
    return ((x >> n) | (x << (32 - n))) & 0xFFFFFFFF

def sigma_0(x):
    return rotr(x, 7) ^ rotr(x, 18) ^ (x >> 3)

def sigma_1(x):
    return rotr(x, 17) ^ rotr(x, 19) ^ (x >> 10)

def sha256_message_schedule(block_bytes):
    assert len(block_bytes) == 64
    W = []

    # W0 ~ W15
    for i in range(16):
        word = struct.unpack(">I", block_bytes[4*i:4*(i+1)])[0]
        W.append(word)

    # W16 ~ W63
    for i in range(16, 64):
        s0 = sigma_0(W[i - 15])
        s1 = sigma_1(W[i - 2])
        val = (W[i - 16] + s0 + W[i - 7] + s1) & 0xFFFFFFFF
        W.append(val)

    return W

def gen_random_block():
    return bytes(random.getrandbits(8) for _ in range(64))

def main(n):
    with open("test_vec.dat", "w") as tf, open("gold_vec.dat", "w") as gf:
        for vec_id in range(n):
            msg = gen_random_block()
            W = sha256_message_schedule(msg)

            # 寫入 test_vec（只寫 W0~W15）
            for i in range(16):
                val = struct.unpack(">I", msg[4*i:4*(i+1)])[0]
                tf.write(f"@{vec_id*16 + i:08x} {val:08x}\n")

            # 寫入 gold_vec（寫 W0~W63）
            for i in range(64):
                gf.write(f"@{vec_id*64 + i:08x} {W[i]:08x}\n")

    print(f"✅ 已產生 {n} 組測試向量，輸出為 test_vec.dat / gold_vec.dat")

if __name__ == "__main__":
    import sys
    if len(sys.argv) != 2:
        print("用法：python gen_vecs.py <產生幾組 n>")
    else:
        main(int(sys.argv[1]))
