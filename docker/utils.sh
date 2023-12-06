GREEN="\033[32m"
COLOR_END="\033[0m"
GITHUB_TOKEN="xxx" # 请替换为你的GitHub Token

function get_dockerhub_latest_tag() {
    # 参数：仓库名
    repo="$1"

    # 设置页数上限
    max_pages=$2

    # 检查仓库名是否具有 "x/x" 这种结构
    if [[ ! $repo =~ .*/.* ]]; then
        # 如果不具有 "x/x" 这种结构，认为它是一个官方仓库，添加 "library/" 前缀
        repo="library/${repo}"
    fi

    # 设置初始URL
    url="https://registry.hub.docker.com/v2/repositories/${repo}/tags?page_size=100"

    # 设置页数计数器
    page_counter=0

    # 循环处理所有页，最多处理10页
    while [[ -n "$url" && $page_counter -lt "$max_pages" ]]
    do
        # 发送请求获取tag信息
        response=$(curl -s "$url")

        # 使用jq工具解析和打印tag信息，选择以 "v" 开头的tag，并忽略包含“latest” 的tag
        echo "$response" | jq -r '.results[].name' | grep -E '^(v|[0-9]+\.[0-9]+)' | grep -v -E '(latest)'

        # 获取下一页的URL
        url=$(echo "$response" | jq -r '.next')

        # Docker Hub 的API在最后一页会返回 "null"，所以我们需要检查并处理这种情况
        if [[ "$url" == "null" ]]
        then
            url=""
        fi

        # 增加页数计数器
        ((page_counter++))
    done | head -n 1
}

function get_github_latest_tag() {
    local full_repo="$1"
    local org; org=$(echo "$full_repo" | cut -d'/' -f1)
    local repo; repo=$(echo "$full_repo" | cut -d'/' -f2)

    # 设置页数上限
    local max_pages="$2"

    # GitHub Token
    local token="$3"

    # 检查参数是否存在
    if [ -z "$full_repo" ] || [ -z "$max_pages" ] || [ -z "$token" ]; then
        echo "Usage: get_github_latest_tag <full_repo> <max-pages> <github-token>"
        return 1
    fi

    local temp_dir; temp_dir=$(mktemp -d)

    # 用于累积所有页面的结果
    local combined_results="$temp_dir/combined.json"

    # 循环获取每页数据
    for i in $(seq 1 "$max_pages"); do
        curl -L \
          -H "Accept: application/vnd.github+json" \
          -H "Authorization: Bearer $token" \
          -H "X-GitHub-Api-Version: 2022-11-28" \
          "https://api.github.com/orgs/${org}/packages/container/${repo}/versions?page=${i}&per_page=100" >> "$combined_results"
    done

    # 使用 jq 从所有页面的合并文件中提取 tag，并获取最新的 tag
    local latest_tag
    latest_tag=$(< "$combined_results" jq -r '.[].metadata.container.tags[] | select((startswith("v") and (. != "latest")))' | sort -Vr | head -n 1)

    # 清理临时文件
    rm -r "$temp_dir"

    # 返回最新的 tag
    echo "$latest_tag"
}

function replace_tag_in_compose_file() {
    # 参数：仓库名 和 docker-compose文件路径
    repo="$1"
    compose_file="$2"

    # 获取最新的非alpha/beta标签
    latest_tag=$(get_dockerhub_latest_tag "$repo" 10)

    # 打印获取的最新标签
    echo -e "${GREEN}Latest tag for $repo: $latest_tag ${COLOR_END}"

    # 使用sed命令替换docker-compose文件中的标签
    # 注意：这将替换文件中所有服务的标签，如果你有多个服务或者只想替换特定服务的标签，你可能需要修改这个命令
    sed -i -e "s|image: ${repo}:.*|image: ${repo}:${latest_tag}|" "$compose_file"
}

function replace_tag_in_env_file() {
    # 参数：仓库名 和 .env文件路径
    repo="$1"
    default_env_file="$2"
    custom_env_file="$3"
    var_name="$4"

    # model=1: github, model=2: dockerhub
    model="$5"

    # 获取最新的标签
    if [[ "$model" == "1" ]]; then
        latest_tag=$(get_github_latest_tag "$repo" 5 "$GITHUB_TOKEN")
    else
        latest_tag=$(get_dockerhub_latest_tag "$repo" 10)
    fi

    # 打印获取的最新标签
    echo -e "${GREEN}latest tag for $repo: $latest_tag ${COLOR_END}"

    # 使用sed命令替换.env文件中的对应环境变量配置
    sed -i -e "s|^${var_name}=.*|${var_name}=${latest_tag}|" "$default_env_file"
    cp "$default_env_file" "$custom_env_file"
}