(ns check
  (:require
    [external.choice]
    [external.settings]
    [generated.flags]
    [generated.report :as report]
    [generated.shapes :as shapes]
    [generated.shapes.area :as area]))


(defn check!
  [expected actual]
  (when (not= expected actual)
    (throw (ex-info "unexpected value" {:expected expected :actual actual}))))


(let [point {:x 1 :y 2}
      rect (area/place {:point point})]
  (check! {:origin point :width 3 :height 4} rect)
  (check! 12 (report/total [{:label "" :origin point :size rect}]))
  (check! 30 (area/area {:origin point :width 5 :height 6})))


(check! {:value 5} (area/count {:value 4}))
(check! 6 (area/shape-count {:count 6}))


(let [packet (area/packet :ready)]
  (check! {:payload :ready} packet)
  (check! :ready (report/status packet)))


(check! true (report/boolean {:payload true}))
(check! 1 (shapes/status-ctor-idx :busy))

(check! {:enabled true} (area/main-flag {:enabled true}))
(check! {:enabled false} (report/external-flag {:enabled false}))
(check! {:value 3} (report/setting {:value 3}))
(check! 7 (report/grams (area/weigh 7)))
