
# >>> juliaup initialize >>>

# !! Contents within this block are managed by juliaup !!

case ":$PATH:" in
    *:"$HOME/.juliaup/bin":*)
        ;;

    *)
        export PATH="$HOME/.juliaup/bin"${PATH:+:${PATH}}
        ;;
esac

# <<< juliaup initialize <<<
