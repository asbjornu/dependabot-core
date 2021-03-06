# frozen_string_literal: true

require "spec_helper"
require "dependabot/dependency_file"
require "dependabot/file_parsers/java_script/npm_and_yarn"
require_relative "../shared_examples_for_file_parsers"

RSpec.describe Dependabot::FileParsers::JavaScript::NpmAndYarn do
  it_behaves_like "a dependency file parser"

  let(:files) { [package_json, lockfile] }
  let(:package_json) do
    Dependabot::DependencyFile.new(
      name: "package.json",
      content: package_json_body
    )
  end
  let(:package_json_body) do
    fixture("javascript", "package_files", "package.json")
  end
  let(:parser) { described_class.new(dependency_files: files, repo: "org/nm") }

  describe "parse" do
    subject(:dependencies) { parser.parse }

    context "with a package-lock.json" do
      let(:lockfile) do
        Dependabot::DependencyFile.new(
          name: "package-lock.json",
          content: lockfile_body
        )
      end
      let(:lockfile_body) do
        fixture("javascript", "npm_lockfiles", "package-lock.json")
      end

      its(:length) { is_expected.to eq(2) }

      context "with a version specified" do
        describe "the first dependency" do
          subject { dependencies.first }

          it { is_expected.to be_a(Dependabot::Dependency) }
          its(:name) { is_expected.to eq("fetch-factory") }
          its(:version) { is_expected.to eq("0.0.1") }
          its(:requirements) do
            is_expected.to eq(
              [
                {
                  requirement: "^0.0.1",
                  file: "package.json",
                  groups: ["dependencies"],
                  source: nil
                }
              ]
            )
          end
        end
      end

      context "that contains bad JSON" do
        let(:lockfile_body) do
          '{ "bad": "json" "no": "comma" }'
        end

        it "raises a DependencyFileNotParseable error" do
          expect { parser.parse }.
            to raise_error(Dependabot::DependencyFileNotParseable) do |error|
              expect(error.file_name).to eq("package-lock.json")
            end
        end
      end

      context "with only dev dependencies" do
        let(:package_json_body) do
          fixture("javascript", "package_files", "only_dev_dependencies.json")
        end
        let(:lockfile_body) do
          fixture("javascript", "npm_lockfiles", "only_dev_dependencies.json")
        end

        describe "the first dependency" do
          subject { dependencies.first }

          it { is_expected.to be_a(Dependabot::Dependency) }
          its(:name) { is_expected.to eq("etag") }
          its(:version) { is_expected.to eq("1.8.1") }
          its(:requirements) do
            is_expected.to eq(
              [
                {
                  requirement: "^1.0.0",
                  file: "package.json",
                  groups: ["devDependencies"],
                  source: nil
                }
              ]
            )
          end
        end
      end

      context "with a private-source dependency" do
        let(:package_json_body) do
          fixture("javascript", "package_files", "private_source.json")
        end
        let(:lockfile_body) do
          fixture("javascript", "npm_lockfiles", "private_source.json")
        end

        its(:length) { is_expected.to eq(3) }

        describe "the first private dependency" do
          subject { dependencies[1] }

          it { is_expected.to be_a(Dependabot::Dependency) }
          its(:name) { is_expected.to eq("chalk") }
          its(:version) { is_expected.to eq("2.3.0") }
          its(:requirements) do
            is_expected.to eq(
              [
                {
                  requirement: "^2.0.0",
                  file: "package.json",
                  groups: ["dependencies"],
                  source: {
                    type: "private_registry",
                    url: "http://registry.npm.taobao.org"
                  }
                }
              ]
            )
          end
        end

        describe "the second private dependency" do
          subject { dependencies.last }

          it { is_expected.to be_a(Dependabot::Dependency) }
          its(:name) { is_expected.to eq("@dependabot/etag") }
          its(:version) { is_expected.to eq("1.8.1") }
          its(:requirements) do
            is_expected.to eq(
              [
                {
                  requirement: "^1.0.0",
                  file: "package.json",
                  groups: ["devDependencies"],
                  source: {
                    type: "private_registry",
                    url: "https://npm.fury.io/dependabot"
                  }
                }
              ]
            )
          end
        end
      end

      context "with an optional dependency" do
        let(:package_json_body) do
          fixture("javascript", "package_files", "optional_dependencies.json")
        end
        let(:lockfile_body) do
          fixture("javascript", "npm_lockfiles", "optional_dependencies.json")
        end

        its(:length) { is_expected.to eq(2) }

        describe "the last dependency" do
          subject { dependencies.last }

          it { is_expected.to be_a(Dependabot::Dependency) }
          its(:name) { is_expected.to eq("etag") }
          its(:version) { is_expected.to eq("1.8.1") }
          its(:requirements) do
            is_expected.to eq(
              [
                {
                  requirement: "^1.0.0",
                  file: "package.json",
                  groups: ["optionalDependencies"],
                  source: nil
                }
              ]
            )
          end
        end
      end

      context "with a path-based dependency" do
        let(:files) { [package_json, lockfile, path_dep] }
        let(:package_json_body) do
          fixture("javascript", "package_files", "path_dependency.json")
        end
        let(:lockfile_body) do
          fixture("javascript", "npm_lockfiles", "path_dependency.json")
        end
        let(:path_dep) do
          Dependabot::DependencyFile.new(
            name: "deps/etag/package.json",
            content: fixture("javascript", "package_files", "etag.json")
          )
        end

        it "doesn't include the path-based dependency" do
          expect(dependencies.length).to eq(3)
          expect(dependencies.map(&:name)).to_not include("etag")
        end
      end

      context "with a git-based dependency" do
        let(:files) { [package_json, lockfile, path_dep] }
        let(:package_json_body) do
          fixture("javascript", "package_files", "git_dependency.json")
        end
        let(:lockfile_body) do
          fixture("javascript", "npm_lockfiles", "git_dependency.json")
        end
        let(:path_dep) do
          Dependabot::DependencyFile.new(
            name: "deps/etag/package.json",
            content: fixture("javascript", "package_files", "etag.json")
          )
        end

        it "doesn't include the path-based dependency" do
          expect(dependencies.length).to eq(3)
          expect(dependencies.map(&:name)).to_not include("etag")
        end
      end

      context "with only a package.json" do
        let(:files) { [package_json] }

        its(:length) { is_expected.to eq(2) }

        describe "the first dependency" do
          subject { dependencies.first }

          it { is_expected.to be_a(Dependabot::Dependency) }
          its(:name) { is_expected.to eq("fetch-factory") }
          its(:version) { is_expected.to be_nil }
          its(:requirements) do
            is_expected.to eq(
              [
                {
                  requirement: "^0.0.1",
                  file: "package.json",
                  groups: ["dependencies"],
                  source: nil
                }
              ]
            )
          end
        end

        context "with a git dependency" do
          let(:package_json_body) do
            fixture("javascript", "package_files", "git_dependency.json")
          end
          its(:length) { is_expected.to eq(3) }

          it "excludes the git dependency" do
            expect { dependencies.map(&:name).to_not include?("is-number") }
          end
        end
      end
    end

    context "with a yarn.lock" do
      let(:lockfile) do
        Dependabot::DependencyFile.new(
          name: "yarn.lock",
          content: lockfile_body
        )
      end
      let(:lockfile_body) do
        fixture("javascript", "yarn_lockfiles", "yarn.lock")
      end

      its(:length) { is_expected.to eq(2) }

      context "with a version specified" do
        describe "the first dependency" do
          subject { dependencies.first }

          it { is_expected.to be_a(Dependabot::Dependency) }
          its(:name) { is_expected.to eq("fetch-factory") }
          its(:version) { is_expected.to eq("0.0.1") }
          its(:requirements) do
            is_expected.to eq(
              [
                {
                  requirement: "^0.0.1",
                  file: "package.json",
                  groups: ["dependencies"],
                  source: nil
                }
              ]
            )
          end
        end
      end

      context "with only dev dependencies" do
        let(:package_json_body) do
          fixture("javascript", "package_files", "only_dev_dependencies.json")
        end
        let(:lockfile_body) do
          fixture("javascript", "yarn_lockfiles", "only_dev_dependencies.lock")
        end

        describe "the first dependency" do
          subject { dependencies.first }

          it { is_expected.to be_a(Dependabot::Dependency) }
          its(:name) { is_expected.to eq("etag") }
          its(:version) { is_expected.to eq("1.8.0") }
          its(:requirements) do
            is_expected.to eq(
              [
                {
                  requirement: "^1.0.0",
                  file: "package.json",
                  groups: ["devDependencies"],
                  source: nil
                }
              ]
            )
          end
        end
      end

      context "with an optional dependency" do
        let(:package_json_body) do
          fixture("javascript", "package_files", "optional_dependencies.json")
        end

        its(:length) { is_expected.to eq(2) }

        describe "the last dependency" do
          subject { dependencies.last }

          it { is_expected.to be_a(Dependabot::Dependency) }
          its(:name) { is_expected.to eq("etag") }
          its(:version) { is_expected.to eq("1.7.0") }
          its(:requirements) do
            is_expected.to eq(
              [
                {
                  requirement: "^1.0.0",
                  file: "package.json",
                  groups: ["optionalDependencies"],
                  source: nil
                }
              ]
            )
          end
        end
      end

      context "with a private-source dependency" do
        let(:package_json_body) do
          fixture("javascript", "package_files", "private_source.json")
        end
        let(:lockfile_body) do
          fixture("javascript", "yarn_lockfiles", "private_source.lock")
        end

        its(:length) { is_expected.to eq(2) }

        describe "the first dependency" do
          subject { dependencies.first }

          it { is_expected.to be_a(Dependabot::Dependency) }
          its(:name) { is_expected.to eq("chalk") }
          its(:version) { is_expected.to eq("2.3.0") }
          its(:requirements) do
            is_expected.to eq(
              [
                {
                  requirement: "^2.0.0",
                  file: "package.json",
                  groups: ["dependencies"],
                  source: {
                    type: "private_registry",
                    url: "http://registry.npm.taobao.org"
                  }
                }
              ]
            )
          end
        end

        describe "the second dependency" do
          subject { dependencies.last }

          it { is_expected.to be_a(Dependabot::Dependency) }
          its(:name) { is_expected.to eq("@dependabot/etag") }
          its(:version) { is_expected.to eq("1.8.0") }
          its(:requirements) do
            is_expected.to eq(
              [
                {
                  requirement: "^1.0.0",
                  file: "package.json",
                  groups: ["devDependencies"],
                  source: {
                    type: "private_registry",
                    url: "https://npm.fury.io/dependabot"
                  }
                }
              ]
            )
          end
        end
      end

      context "with a path-based dependency" do
        let(:files) { [package_json, lockfile, path_dep] }
        let(:package_json_body) do
          fixture("javascript", "package_files", "path_dependency.json")
        end
        let(:lockfile_body) do
          fixture("javascript", "yarn_lockfiles", "path_dependency.lock")
        end
        let(:path_dep) do
          Dependabot::DependencyFile.new(
            name: "deps/etag/package.json",
            content: fixture("javascript", "package_files", "etag.json")
          )
        end

        it "doesn't include the path-based dependency" do
          expect(dependencies.length).to eq(3)
          expect(dependencies.map(&:name)).to_not include("etag")
        end
      end

      context "with workspaces" do
        let(:package_json_body) do
          fixture("javascript", "package_files", "workspaces.json")
        end
        let(:lockfile_body) do
          fixture("javascript", "yarn_lockfiles", "workspaces.lock")
        end
        let(:files) { [package_json, lockfile, package1, other_package] }
        let(:package1) do
          Dependabot::DependencyFile.new(
            name: "packages/package1/package.json",
            content: fixture("javascript", "package_files", "package1.json")
          )
        end
        let(:other_package) do
          Dependabot::DependencyFile.new(
            name: "other_package/package.json",
            content: fixture(
              "javascript",
              "package_files",
              "other_package.json"
            )
          )
        end

        its(:length) { is_expected.to eq(3) }

        describe "the last dependency" do
          subject { dependencies.last }

          it { is_expected.to be_a(Dependabot::Dependency) }
          its(:name) { is_expected.to eq("etag") }
          its(:version) { is_expected.to eq("1.8.1") }
          its(:requirements) do
            is_expected.to match_array(
              [
                {
                  requirement: "^1.1.0",
                  file: "packages/package1/package.json",
                  groups: ["devDependencies"],
                  source: nil
                },
                {
                  requirement: "^1.0.0",
                  file: "other_package/package.json",
                  groups: ["devDependencies"],
                  source: nil
                }
              ]
            )
          end
        end
      end
    end
  end
end
