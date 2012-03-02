#!/bin/sh
# adapted from http://www.theleagueofpaul.com/hg-to-git

hg_src_url=$1
git_dst_url=$2

# get a temporary directory a workspace
temp_dir=`mktemp -d /tmp/hg_to_git_migration.XXXXXXXXX`

# clone the remote hg repo locally
hg clone $hg_src_url $temp_dir
cd $temp_dir

# get a list of the hg repo's branches other than the default branch
branches=`hg branches | grep -v default | awk '{print $1}'`

# map the default branch to master
hg bookmark -r default master

# map each hg branch to a git branch
# we have to prepend "bookmark_" because hg
# branches and bookmarks share a namespace
for branch in $branches; do
  hg bookmark -r $branch bookmark_$branch
done

# initialize local git repository
hg gexport
mv .hg/git .git
rm -rf .hg
git init

# rename bookmark branches to their original name
for branch in $branches; do
  git branch -m bookmark_$branch $branch
done

# point at origin
git remote add origin $git_dst_url

# filter authors
git checkout master -f
git filter-branch --env-filter '

an="$GIT_AUTHOR_NAME"
am="$GIT_AUTHOR_EMAIL"
cn="$GIT_COMMITTER_NAME"
cm="$GIT_COMMITTER_EMAIL"

if [ "$GIT_AUTHOR_NAME" = "author1" ]
then
    cn="CommitterFirst1 CommitterLast1"
    cm="committer1@email.com"
    an="AuthorFirst1 AuthorLast2"
    am="author1@email.com"
elif [ "$GIT_AUTHOR_NAME" = "author2" ]
then
    cn="CommitterFirst2 CommitterLast2"
    cm="committer2@email.com"
    an="AuthorFirst2 AuthorLast2"
    am="author2@email.com"
fi
' -- --all

# push master branch
git push origin master

# push each branch
for branch in $branches; do
  git push origin $branch
done

# clean up after ourselves
rm -rf $temp_dir

