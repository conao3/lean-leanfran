(ns build
  (:require
    [clojure.edn :as edn]
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
