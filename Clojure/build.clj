(ns build
  (:require
    [clojure.edn :as edn]
    [clojure.string :as str]
    [clojure.tools.build.api :as b]
    [deps-deploy.deps-deploy :as dd]))


(def project (get-in (edn/read-string (slurp "deps.edn")) [:aliases :build :build/project]))

(def lib (:lib project))
(def version (:version project))
(def url (:url project))

(def src-dirs ["src"])
(def resource-dirs ["resources"])
(def class-dir "target/classes")
(def jar-file (format "target/%s-%s.jar" (name lib) version))

(def basis (delay (b/create-basis {:project "deps.edn"})))


(defn clean
  [_]
  (b/delete {:path "target"}))


(defn jar
  [_]
  (clean nil)
  (b/write-pom {:class-dir class-dir
                :lib lib
                :version version
                :basis @basis
                :src-dirs src-dirs
                :resource-dirs resource-dirs
                :scm {:url url
                      :connection (str "scm:git:" url ".git")
                      :tag (str "v" version)}
                :pom-data [[:description (:description project)]
                           [:url url]
                           [:licenses
                            [:license
                             [:name (:license project)]
                             [:url "https://www.apache.org/licenses/LICENSE-2.0"]]]]})
  (b/copy-dir {:src-dirs (concat src-dirs resource-dirs)
               :target-dir class-dir})
  (b/jar {:class-dir class-dir
          :jar-file jar-file}))


(defn deploy
  [_]
  (jar nil)
  (dd/deploy {:installer :remote
              :artifact jar-file
              :pom-file (b/pom-path {:lib lib :class-dir class-dir})}))


(def ^:private version-sites
  "Files holding the version, with a pattern whose group 2 is the version."
  [["deps.edn" #"(:version \")([0-9]+\.[0-9]+\.[0-9]+)(\")"]
   ["Main.lean" #"(def version : String := \")([0-9]+\.[0-9]+\.[0-9]+)(\")"]
   ["src/lean_clj/core.clj" #"(\(def generator-version\n(?:  .*\n)*?  \")([0-9]+\.[0-9]+\.[0-9]+)(\")"]
   ["flake.nix" #"(version = \")([0-9]+\.[0-9]+\.[0-9]+)(\";)"]
   ["README.md" #"(\{:mvn/version \")([0-9]+\.[0-9]+\.[0-9]+)(\"\})"]
   ["README.md" #"(github:conao3/lean-clj/v)([0-9]+\.[0-9]+\.[0-9]+)()"]])


(defn- next-version
  [v part]
  (let [[major minor patch] (map parse-long (str/split v #"\."))]
    (case part
      major (str (inc major) ".0.0")
      minor (str major "." (inc minor) ".0")
      patch (str major "." minor "." (inc patch)))))


(defn bump
  "Raise the `:part` (`patch`, `minor`, or `major`) of the version in every
  file that holds it, and print the new version."
  [{:keys [part]}]
  (let [v (next-version version (symbol (name part)))]
    (doseq [[f re] version-sites]
      (let [s (slurp f)]
        (when-not (re-find re s)
          (throw (ex-info (str "build: no version in " f) {:file f :pattern re})))
        (spit f (str/replace s re (fn [[_ pre _ post]] (str pre v post))))))
    (println v)))
