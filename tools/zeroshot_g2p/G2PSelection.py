from __future__ import print_function
import numpy as np
from queue import PriorityQueue, Queue, Empty
import sys
import time

MAX_VALUE=999999999.0


class BatchActiveSubset(object):
    '''
        BatchActiveSubset:
            A class controlling the parameters of the batch active learner.
            It takes as input the submodular objective function, the budget,
            which is the constraint in the optimization problem, a list of words
            used to learn some feature extractors or edge similarity for
            instance, a list of words from which we will select upto budget's
            worth, and a few optional arguments that control the selection.
            Input: word_tokens in the format output by words_to_tokens
            
            Inputs: 
                objective -- The submodular objective to optimize. This is
                             implemented as a class
                budget    -- The contraint in the submodular optimization problem
                wordlist  -- A list of words from which to select budget's
                             worth
                cost=1 -- The cost of select each word for g2p training. The cost
                          could be things such as the length, some power of the
                          length, the word frequency, etc..
    '''
    def __init__(self, objective, budget, wordlist,
                cost=lambda x: 1, cost_select=False):
        self.objective = objective # An objective object
        self.budget = budget
        self.test_wordlist = wordlist
        self.cost = cost
        self.cost_select = cost_select 
        self.KL = [] 
 
    def run_lazy(self):
        '''
            This implements Minoux's Lazy Greedy (Accelterated) subset
            selection algorithm.  
        '''
        start = time.time()
        print("START: ", start)
        S = []
        set_value = 0.0
        total_cost = 0.0
        remaining_budget = self.budget

        # Initialize Priority Queue
        upper_bounds = PriorityQueue()
        self.objective.set_subset(S)
        for i, w in enumerate(self.test_wordlist):
            if (self.cost(w) <= self.budget):
                upper_bounds.put((-MAX_VALUE, i))    
        
        # Main loop (Continue until budget is reached, or no elements remain) 
        while total_cost < self.budget and not upper_bounds.empty():
            alpha_idx, idx = upper_bounds.get(False)
       
            if (self.cost(self.test_wordlist[idx]) > remaining_budget):
                continue;
                 
            new_set_value = self.objective.run(idx)
            gain = (new_set_value - set_value)
            assert gain > -1e-09 , "ERROR: Expected gain >= 0" 
            if self.cost_select:
                gain /= self.cost(self.test_wordlist[idx]) ** 0.2
            # This is for the case when idx is the last element 
            try: 
                max_val, idx_max = upper_bounds.get(False)
                upper_bounds.put((max_val, idx_max))
            except Empty:
                max_val = 0.0 

            if (gain >= -max_val):
                S.append(idx)
                self.objective.add_to_subset(idx)
                total_cost += self.cost(self.test_wordlist[idx])
                set_value = new_set_value
                self.KL.append(self.objective.compute_kl())
                remaining_budget = self.budget - total_cost
                
                # Print some things for logging
                print(self.test_wordlist[idx].encode('utf-8'), "Consumed: ", total_cost, "/", self.budget,
                    ":  +", self.cost(self.test_wordlist[idx]), end=" : ")
                print("Set value: ", set_value, end=" : ")
                print("Gain: ", gain, end=" : ")
                print("Remaining Candidates: ", upper_bounds.qsize(), end=" : ")
                print("Now: ", time.time() - start)
            else:
                upper_bounds.put((-gain, idx))
                
        return [self.test_wordlist[idx] for idx in S]


class RandomSubset(object):
    def __init__(self, objective, budget, wordlist, cost=lambda x: 1, cost_select=False):
        self.budget = budget
        self.test_wordlist = wordlist
        self.cost = cost
    
    def run(self):
        ranked_words = []
        V_minus_S = [] 
        for i in np.random.choice(range(len(self.test_wordlist)), size=len(self.test_wordlist), replace=False):
            w = self.test_wordlist[i]
            if (self.cost(w) <= self.budget):
                V_minus_S.append((self.cost(w), w))
        total_cost = 0.0
        remaining_budget = self.budget
        
        while total_cost < self.budget and len(V_minus_S) > 0:
            cost_w_star, w_star = V_minus_S.pop()
            if cost_w_star <= remaining_budget: 
                ranked_words.append(w_star)
                total_cost += cost_w_star
                print(w_star.encode('utf-8'), "Consumed: ", total_cost, "/", self.budget, ": + ", cost_w_star, end=" : ")
                remaining_budget = self.budget - total_cost
                print("Remaining Candidates: ", len(V_minus_S))
            
        return ranked_words
    
    def run_lazy(self):
        return self.run()


class Greedy(object):
    def __init__(self, objective, budget, wordlist, cost=lambda x: 1, cost_select=False):
        self.budget = budget
        self.objective = objective
        self.test_wordlist = wordlist
        self.cost = cost
        self.cost_select = cost_select

    def run(self):
        start = time.time()
        S = []
        V_minus_S = [(i, w) for i, w in enumerate(self.test_wordlist)] 
        set_value = 0.0
        total_cost = 0.0
        remaining_budget = self.budget

        total_cost = 0.0
        remaining_budget = self.budget
        self.objective.set_subset(S)
        
        while total_cost < self.budget and len(V_minus_S) > 0:
            if self.cost_select:
                gains = [(self.objective.run(i) - set_value)/self.cost(w) for i, w in V_minus_S]
            else:
                gains = [(self.objective.run(i) - set_value) for i, w in V_minus_S]
            max_gain = max(gains)
            idx, word_to_add = V_minus_S[gains.index(max_gain)] 
            if self.cost(word_to_add) <= remaining_budget: 
                S.append(word_to_add)
                self.objective.add_to_subset(idx)
                total_cost += self.cost(word_to_add)
                set_value += max_gain 
                print(word_to_add.encode('utf-8'), "Consumed: ", total_cost, "/", self.budget, ": + ", self.cost(word_to_add), end=" : ")
                print("Set value: ", set_value, end=" : ")
                print("Gain: ", max_gain, end=" : ")
                remaining_budget = self.budget - total_cost
                V_minus_S.remove((idx, word_to_add))
                print("Remaining Candidates: ", len(V_minus_S), end=" : ")
                print("Now: ", time.time() - start)
        return S
    
    def run_lazy(self):
        return self.run()


