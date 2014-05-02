#!/usr/bin/python3
import argparse
import subprocess
import sys
import json


def current_version():
    process = subprocess.Popen(
        ["git", "describe", "--abbrev=0", "--tags"], stdout=subprocess.PIPE)
    for version in process.stdout:
        break
    return str(version, 'utf-8').strip()


def check_tag(tag):
    process = subprocess.Popen(["git", "tag"], stdout=subprocess.PIPE)
    for existing_tag in process.stdout:
        if tag == str(existing_tag, 'utf-8').strip():
            return False
    return True


def generate_changelog(version):
    try:
        f = open("datas/changelog.json", 'r')
    except Exception as err:
        print("Failed to open the changelog file: %s" % err)
        sys.exit(4)
    try:
        changelog = json.load(f)
    except Exception as err:
        print("Failed to parse the changelog file: %s" % err)
        sys.exit(4)
    f.close()
    changelog[version] = []
    features = []
    bugs = []

    process = subprocess.Popen(
        ["git", "log", "%s..HEAD" % current_version()], stdout=subprocess.PIPE)
    for line in process.stdout:
        stripedLine = str(line, 'utf-8').strip()
        if stripedLine.startswith("[B]"):
            bugs.append({"type": "bug", "text": stripedLine[3:].strip()})
        if stripedLine.startswith("[F]"):
            features.append(
                {"type": "feature", "text": stripedLine[3:].strip()})
    for feature in features:
        changelog[version].append(feature)
    for bug in bugs:
        changelog[version].append(bug)
    try:
        f = open("datas/changelog.json", 'w')
        json.dump(changelog, f, sort_keys=True, indent=2)
    except:
        print("Failed to write the changelog file")
        sys.exit(4)
    f.close()

    print("Changelog:")
    for entry in changelog[version]:
        print("%s: %s" % (entry["type"].upper(), entry["text"]))

    print("Generate HTML Changelog")
    with open("datas/changelog.html", "w") as fh:
        for version in sorted(changelog):
            print(version)
            fh.write('<b>%s</b> : <br>' % version)
            for entry in changelog[version]:
                fh.write('%s : %s<br>' % (entry['type'].title(),
                                          entry['text'].title()))
            fh.write('<br>')


def write_version(version, codename):
    try:
        f = open("version.pri", 'w')
        f.write("VERSION=%s\nCODENAME=%s\n" % (version, codename))
        f.close()
    except:
        print("Failed to write the version file")
        sys.exit(5)
    try:
        yaml = None
        import re
        with open('rpm/ownNotes.yaml', 'rb') as fh:
            yaml = fh.read()
        if yaml is not None:
            re.sub('^Version: \'(.*)\'$', version, yaml, flags=re.MULTILINE)
            with open('rpm/ownNotes.yaml', 'wb') as fh:
                fh.write(yaml)
    except:
        print ('Failed to write the yaml file')


def commit_and_tag(version):
    subprocess.Popen(["git", "commit", "-a", "-m", "Bump to version %s" %
                     version], stdout=subprocess.PIPE)
    subprocess.Popen(["git", "tag", version], stdout=subprocess.PIPE)


def push(version):
    subprocess.Popen(["git", "push", "origin", "master"],
                     stdout=subprocess.PIPE)
    subprocess.Popen(["git", "push", "origin", version],
                     stdout=subprocess.PIPE)

parser = argparse.ArgumentParser(description='ownNotes release script')
parser.add_argument('version', metavar='version', type=str, nargs='?',
                    help='Version to be used for the release')
parser.add_argument('codename', metavar='codename', type=str, nargs='?',
                    help='Release codename')
parser.add_argument('--push-only', action='store_true',
                    help='If this release is a major release')
parser.add_argument('--changelog-only', action='store_true',
                    help='Create html changelog only')

args = parser.parse_args()
version = args.version
codename = args.codename
push_only = args.push_only
changelog_only = args.changelog_only

if push_only and version is None:
    parser.print_help()
    sys.exit(1)

if version is None:
    print("Current version: %s" % current_version())
    sys.exit(2)

if changelog_only:
    generate_changelog(version)
    sys.exit(4)

version = version.strip()

if not push_only:
    print("Preparing the release of ownNotes")
    print("")
    print("Version: %s" % version)
    if codename is not None:
        print("Codename: %s" % codename)

    if not check_tag(version):
        print("Error: version %s already exists" % version)
        sys.exit(3)
    print("")

    generate_changelog(version)
    write_version(version, codename)
    print("")
    print("Committing and tagging the change")
    commit_and_tag(version)

print("")
print("Pushing to the server")
if check_tag(version):
    print("Error: tag is not set")
    sys.exit(6)
push(version)
