verbana.sql = {}

local lfs = verbana.ie.lfs

function verbana.sql.load_files(base_path)
    local contents = {}
    for file in lfs.dir(base_path) do
        if file ~= "." and file ~= ".." then
            local file_path = base_path .. DIR_DELIM .. file
            local attr = lfs.attributes(file_path)
            if attr.mode == "directory" then
                contents[file] = verbana.sql.load_files(file_path)
            elseif file:match(".*\\.sql$") then
                contents[file] = verbana.util.load_file(file_path)
            end
        end
    end
    return contents
end

--verbana.dofile("sql", "sqlite", "init")
verbana.dofile("sql", "postgres", "init")
