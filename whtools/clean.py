import os
files_to_delete = [
    r"H:\新软件\3D脚本\车位自制\test_units.ms",
    r"H:\新软件\3D脚本\线条平分连接\线条平分 - 副本.ms",
    r"H:\新软件\3D脚本\线条平分连接\线条平分.ms",
    r"H:\新软件\3D脚本\偏移\偏移+ - 副本.ms",
    r"H:\新软件\3D脚本\片窗\片窗 - 副本.ms",
    r"H:\新软件\3D脚本\孤立\隔离独立空间工具 - 副本.ms",
    r"H:\新软件\3D脚本\孤立\隔离独立空间工具_安装版.ms"
]
for f in files_to_delete:
    try:
        os.remove(f)
        print("Deleted: " + f)
    except Exception as e:
        print("Failed to delete " + f + ": " + str(e))
print("Deletion complete.")
